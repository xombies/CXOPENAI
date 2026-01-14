import sql from "@/app/api/utils/sql";

export async function POST(request) {
  try {
    const { prompt, loop, lastAgentC, lastAgentX } = await request.json();

    // Rate limiting - 10 debates per day per IP
    const DAILY_LIMIT = 10;
    const userIP =
      request.headers.get("x-forwarded-for")?.split(",")[0] ||
      request.headers.get("x-real-ip") ||
      "unknown";

    // Get or create usage record
    const usageResult = await sql`
      SELECT * FROM usage_logs 
      WHERE ip_address = ${userIP}
    `;

    let usageRecord = usageResult[0];
    const today = new Date().toISOString().split("T")[0];

    if (!usageRecord) {
      // Create new record
      await sql`
        INSERT INTO usage_logs (ip_address, debate_count, last_reset_date)
        VALUES (${userIP}, 1, ${today})
      `;
      usageRecord = { debate_count: 1 };
    } else {
      // Check if we need to reset (new day)
      if (usageRecord.last_reset_date.toISOString().split("T")[0] !== today) {
        await sql`
          UPDATE usage_logs 
          SET debate_count = 1, last_reset_date = ${today}, updated_at = CURRENT_TIMESTAMP
          WHERE ip_address = ${userIP}
        `;
        usageRecord.debate_count = 1;
      } else {
        // Check limit
        if (usageRecord.debate_count >= DAILY_LIMIT) {
          return Response.json(
            {
              error: "Daily limit reached",
              limit: DAILY_LIMIT,
              remaining: 0,
            },
            { status: 429 },
          );
        }
        // Increment count
        await sql`
          UPDATE usage_logs 
          SET debate_count = debate_count + 1, updated_at = CURRENT_TIMESTAMP
          WHERE ip_address = ${userIP}
        `;
        usageRecord.debate_count += 1;
      }
    }

    // If loop mode, we need the last messages from both agents
    if (loop) {
      if (!lastAgentC || !lastAgentX) {
        return Response.json(
          { error: "Loop mode requires lastAgentC and lastAgentX" },
          { status: 400 },
        );
      }

      // In loop mode, Agent C responds to Agent X's last message
      // and Agent X responds to Agent C's last message
      const agentCMessages = [
        {
          role: "system",
          content:
            "You are Agent C, a logical and systematic AI engineer. You approach problems with precision, structured thinking, and data-driven methodologies. You believe in proven architectures, rigorous testing, and scalable solutions. Keep your response focused and concise.",
        },
        {
          role: "user",
          content: "Agent X says: " + lastAgentX,
        },
      ];

      const agentXMessages = [
        {
          role: "system",
          content:
            "You are Agent X, a creative and innovative AI engineer. You approach problems with imagination, experimental thinking, and cutting-edge methodologies. You believe in pushing boundaries, trying novel architectures, and embracing emerging technologies. Keep your response focused and concise.",
        },
        {
          role: "user",
          content: "Agent C says: " + lastAgentC,
        },
      ];

      // Build absolute URL for integration
      const baseUrl =
        process.env.APP_URL || `https://${request.headers.get("host")}`;
      const integrationUrl = `${baseUrl}/integrations/chat-gpt/conversationgpt4`;

      // Get responses from both agents
      const [agentCResponse, agentXResponse] = await Promise.all([
        fetch(integrationUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ messages: agentCMessages }),
        }),
        fetch(integrationUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ messages: agentXMessages }),
        }),
      ]);

      if (!agentCResponse.ok || !agentXResponse.ok) {
        const agentCError = !agentCResponse.ok
          ? await agentCResponse.text()
          : null;
        const agentXError = !agentXResponse.ok
          ? await agentXResponse.text()
          : null;
        console.error("Agent C error:", agentCError);
        console.error("Agent X error:", agentXError);
        throw new Error(
          `Failed to get responses from agents. Agent C: ${agentCResponse.status}, Agent X: ${agentXResponse.status}`,
        );
      }

      const agentCData = await agentCResponse.json();
      const agentXData = await agentXResponse.json();

      const agentCText = agentCData.choices[0].message.content;
      const agentXText = agentXData.choices[0].message.content;

      return Response.json({
        agentC: agentCText,
        agentX: agentXText,
        remaining: DAILY_LIMIT - usageRecord.debate_count,
      });
    }

    // Original prompt-based mode
    if (!prompt) {
      return Response.json({ error: "Prompt is required" }, { status: 400 });
    }

    // Message arrays for each agent - each responds to the same prompt
    const agentCMessages = [
      {
        role: "system",
        content:
          "You are Agent C, a logical and systematic AI engineer. You approach problems with precision, structured thinking, and data-driven methodologies. You believe in proven architectures, rigorous testing, and scalable solutions. Keep your response focused and concise.",
      },
      {
        role: "user",
        content: prompt,
      },
    ];

    const agentXMessages = [
      {
        role: "system",
        content:
          "You are Agent X, a creative and innovative AI engineer. You approach problems with imagination, experimental thinking, and cutting-edge methodologies. You believe in pushing boundaries, trying novel architectures, and embracing emerging technologies. Keep your response focused and concise.",
      },
      {
        role: "user",
        content: prompt,
      },
    ];

    // Build absolute URL for integration
    const baseUrl =
      process.env.APP_URL || `https://${request.headers.get("host")}`;
    const integrationUrl = `${baseUrl}/integrations/chat-gpt/conversationgpt4`;

    // Get single responses from both agents
    const [agentCResponse, agentXResponse] = await Promise.all([
      fetch(integrationUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: agentCMessages }),
      }),
      fetch(integrationUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: agentXMessages }),
      }),
    ]);

    if (!agentCResponse.ok || !agentXResponse.ok) {
      const agentCError = !agentCResponse.ok
        ? await agentCResponse.text()
        : null;
      const agentXError = !agentXResponse.ok
        ? await agentXResponse.text()
        : null;
      console.error("Agent C error:", agentCError);
      console.error("Agent X error:", agentXError);
      throw new Error(
        `Failed to get responses from agents. Agent C: ${agentCResponse.status}, Agent X: ${agentXResponse.status}`,
      );
    }

    const agentCData = await agentCResponse.json();
    const agentXData = await agentXResponse.json();

    const agentCText = agentCData.choices[0].message.content;
    const agentXText = agentXData.choices[0].message.content;

    return Response.json({
      agentC: agentCText,
      agentX: agentXText,
      remaining: DAILY_LIMIT - usageRecord.debate_count,
    });
  } catch (error) {
    console.error("Error in dual-agent-chat:", error);
    return Response.json(
      { error: error.message || "Failed to get responses" },
      { status: 500 },
    );
  }
}
