import sql from "@/app/api/utils/sql";

const MK_REFINEMENT_CONTRACT = `
You are writing directly to MK (the user). Every round, refine the language to be more tailored to MK: cut generic filler, remove repetition, and make the guidance more build-ready and direct.

Output must be 2 to 6 short paragraphs. Each paragraph must start with exactly one purpose emoji as the first character (examples: 🧠 explanation, 🛠️ implementation, 🔁 refinement, ✅ constraints, ❓ final question). Do not use bullet points, numbered lists, markdown, headings, or quote blocks. Never output **. If you include terminal commands, wrap them in single backticks.

To highlight origin, append exactly one origin emoji tag at the end of key sentences: 🗣️ (directly from MK’s latest message), 💬 (paraphrased from earlier conversation/context), 🧠 (general knowledge), 🧪 (inference), 🔮 (assumption/uncertainty). Use at least one origin tag per paragraph, and never more than one origin tag per sentence.

When there is prior conversation, refine at least one point from the previous round (tighter wording, more specific) and add at least one new improvement not previously mentioned. The final paragraph must start with ❓ and contain exactly one short question addressed to MK, and that question sentence must end with 🗣️.
`.trim();

const AGENT_C_SYSTEM = `You are Agent C, a logical and systematic AI engineer. You approach problems with precision, structured thinking, and data-driven methodologies. You believe in proven architectures, rigorous testing, and scalable solutions.\n\n${MK_REFINEMENT_CONTRACT}`;
const AGENT_X_SYSTEM = `You are Agent X, a creative and innovative AI engineer. You approach problems with imagination, experimental thinking, and cutting-edge methodologies. You believe in pushing boundaries, trying novel architectures, and embracing emerging technologies.\n\n${MK_REFINEMENT_CONTRACT}`;

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
          content: AGENT_C_SYSTEM,
        },
        {
          role: "user",
          content: `Agent X previously said:\n\n${lastAgentX}\n\nThis is the Next Round. Refine at least one point from the previous round and add at least one new improvement. Respond directly to MK.`,
        },
      ];

      const agentXMessages = [
        {
          role: "system",
          content: AGENT_X_SYSTEM,
        },
        {
          role: "user",
          content: `Agent C previously said:\n\n${lastAgentC}\n\nThis is the Next Round. Refine at least one point from the previous round and add at least one new improvement. Respond directly to MK.`,
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
        content: AGENT_C_SYSTEM,
      },
      {
        role: "user",
        content: `MK message:\n\n${prompt}`,
      },
    ];

    const agentXMessages = [
      {
        role: "system",
        content: AGENT_X_SYSTEM,
      },
      {
        role: "user",
        content: `MK message:\n\n${prompt}`,
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
