"use client";

import { useState, useCallback } from "react";
import { Send } from "lucide-react";

export default function DualAgentChat() {
  const [prompt, setPrompt] = useState("");
  const [conversation, setConversation] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [remaining, setRemaining] = useState(null);

  const handleSubmit = useCallback(
    async (e) => {
      e.preventDefault();
      if (!prompt.trim() || loading) return;

      const userPrompt = prompt.trim();
      setPrompt("");
      setError(null);
      setLoading(true);

      setConversation((prev) => [
        ...prev,
        { type: "user", content: userPrompt },
      ]);

      try {
        const response = await fetch("/api/dual-agent-chat", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ prompt: userPrompt }),
        });

        if (!response.ok) {
          throw new Error(`Response failed with status ${response.status}`);
        }

        const data = await response.json();

        if (response.status === 429) {
          setError(
            `Daily limit reached (${data.limit} debates per day). Please try again tomorrow!`,
          );
          setRemaining(0);
          setLoading(false);
          return;
        }

        setConversation((prev) => [
          ...prev,
          {
            type: "debate",
            agentC: data.agentC,
            agentX: data.agentX,
          },
        ]);

        if (data.remaining !== undefined) {
          setRemaining(data.remaining);
        }
      } catch (err) {
        console.error(err);
        setError("Failed to get responses from agents. Please try again.");
      } finally {
        setLoading(false);
      }
    },
    [prompt, loading],
  );

  const handleLoop = useCallback(async () => {
    if (loading || conversation.length === 0) return;

    // Find the last debate in the conversation
    const lastDebate = [...conversation]
      .reverse()
      .find((msg) => msg.type === "debate");
    if (!lastDebate) return;

    setError(null);
    setLoading(true);

    try {
      const response = await fetch("/api/dual-agent-chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          loop: true,
          lastAgentC: lastDebate.agentC,
          lastAgentX: lastDebate.agentX,
        }),
      });

      if (!response.ok) {
        throw new Error(`Response failed with status ${response.status}`);
      }

      const data = await response.json();

      if (response.status === 429) {
        setError(
          `Daily limit reached (${data.limit} debates per day). Please try again tomorrow!`,
        );
        setRemaining(0);
        setLoading(false);
        return;
      }

      setConversation((prev) => [
        ...prev,
        {
          type: "debate",
          agentC: data.agentC,
          agentX: data.agentX,
        },
      ]);

      if (data.remaining !== undefined) {
        setRemaining(data.remaining);
      }
    } catch (err) {
      console.error(err);
      setError("Failed to get loop responses from agents. Please try again.");
    } finally {
      setLoading(false);
    }
  }, [loading, conversation]);

  // Show loop button if there's at least one debate in the conversation
  const showLoopButton = conversation.some((msg) => msg.type === "debate");

  return (
    <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-white to-purple-50">
      {/* Enhanced header with larger AgentT101 */}
      <div className="border-b border-slate-200/60 bg-white/70 backdrop-blur-xl sticky top-0 z-40 shadow-sm">
        <div className="max-w-6xl mx-auto px-4 md:px-8 py-3 md:py-6">
          <div className="text-center">
            {/* AgentX vs AgentC title with AgentT101 in middle - responsive */}
            <div className="flex flex-col md:flex-row items-center justify-center gap-2 md:gap-6 mb-2 md:mb-3">
              <h1
                className="text-xl md:text-4xl"
                style={{
                  fontFamily:
                    '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
                }}
              >
                <span style={{ fontWeight: 100 }}>Agent</span>
                <span style={{ fontWeight: 300 }}>X</span>
              </h1>
              <div className="relative">
                <div className="absolute -inset-2 bg-gradient-to-r from-purple-400 via-indigo-400 to-blue-400 rounded-full opacity-30 blur-xl animate-pulse"></div>
                <img
                  src="https://ucarecdn.com/8d994cac-4bb2-4343-b921-1e65821517c3/"
                  alt="Agent T101"
                  className="relative w-14 h-14 md:w-28 md:h-28 object-contain drop-shadow-2xl transition-transform duration-500 hover:scale-110"
                  style={{
                    animation: "float 3s ease-in-out infinite",
                  }}
                />
              </div>
              <h1
                className="text-xl md:text-4xl"
                style={{
                  fontFamily:
                    '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
                }}
              >
                <span style={{ fontWeight: 100 }}>Agent</span>
                <span style={{ fontWeight: 300 }}>C</span>
              </h1>
            </div>
            {/* Tagline - responsive text */}
            <p className="text-[10px] md:text-sm text-slate-600 max-w-3xl mx-auto px-4">
              Watch two AI engineers debate technical topics from completely
              different perspectives
            </p>
          </div>
        </div>
      </div>

      {/* Main arena - responsive padding */}
      <div className="max-w-6xl mx-auto px-4 md:px-8 py-8 md:py-16 pb-40 md:pb-48">
        <div className="space-y-8 md:space-y-16">
          {conversation.map((message, idx) => (
            <div key={idx} className="space-y-6 md:space-y-8">
              {message.type === "user" && (
                <div className="mb-8 md:mb-12">
                  <div className="max-w-4xl mx-auto text-center">
                    <div className="flex items-center justify-center gap-2 mb-4 md:mb-6">
                      <div className="w-2 h-2 rounded-full bg-indigo-500"></div>
                      <span className="text-xs font-bold text-slate-400 uppercase tracking-[0.2em]">
                        Debate Topic
                      </span>
                      <div className="w-2 h-2 rounded-full bg-indigo-500"></div>
                    </div>
                    <div className="bg-gradient-to-br from-white to-slate-50 border-2 border-slate-200 rounded-2xl md:rounded-3xl px-6 md:px-12 py-6 md:py-10 shadow-xl">
                      <p className="text-base md:text-xl text-slate-900 leading-relaxed font-semibold">
                        {message.content}
                      </p>
                    </div>
                  </div>
                </div>
              )}

              {message.type === "debate" && (
                <div className="space-y-6 md:space-y-12">
                  <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 md:gap-8">
                    {/* Agent X - Enhanced & Responsive */}
                    <div className="group relative">
                      <div className="absolute -inset-1 bg-gradient-to-br from-purple-400 via-pink-400 to-purple-500 rounded-2xl md:rounded-3xl opacity-20 group-hover:opacity-30 blur-xl transition-all duration-500"></div>
                      <div className="relative bg-white border-2 border-purple-200/60 rounded-2xl md:rounded-3xl overflow-hidden shadow-xl hover:shadow-2xl transition-all duration-300 hover:-translate-y-1">
                        <div className="bg-gradient-to-br from-purple-50 to-pink-50 px-4 md:px-8 py-4 md:py-8 border-b-2 border-purple-200/60">
                          <div className="flex items-start gap-3 md:gap-6">
                            <img
                              src="https://ucarecdn.com/82e21364-f8e6-4526-9464-16cac4cfaba6/-/format/auto/"
                              alt="Agent X"
                              className="w-20 h-20 md:w-32 md:h-32 object-contain flex-shrink-0 drop-shadow-lg"
                            />
                            <div className="flex-1">
                              <div className="text-base md:text-lg font-bold text-slate-900 mb-1">
                                Agent X
                              </div>
                              <div className="text-xs md:text-sm text-purple-700 font-semibold mb-2">
                                Creative AI Engineer
                              </div>
                              <div className="flex flex-wrap gap-1 md:gap-2">
                                <span className="text-xs px-2 md:px-3 py-1 bg-purple-100 text-purple-700 rounded-full font-medium">
                                  Innovative
                                </span>
                                <span className="text-xs px-2 md:px-3 py-1 bg-pink-100 text-pink-700 rounded-full font-medium">
                                  Experimental
                                </span>
                              </div>
                            </div>
                          </div>
                        </div>
                        <div className="px-4 md:px-8 py-4 md:py-8">
                          <p className="text-slate-700 leading-relaxed whitespace-pre-wrap text-sm md:text-[15px]">
                            {message.agentX}
                          </p>
                        </div>
                      </div>
                    </div>

                    {/* Agent C - Enhanced & Responsive */}
                    <div className="group relative">
                      <div className="absolute -inset-1 bg-gradient-to-br from-blue-400 via-cyan-400 to-blue-500 rounded-2xl md:rounded-3xl opacity-20 group-hover:opacity-30 blur-xl transition-all duration-500"></div>
                      <div className="relative bg-white border-2 border-blue-200/60 rounded-2xl md:rounded-3xl overflow-hidden shadow-xl hover:shadow-2xl transition-all duration-300 hover:-translate-y-1">
                        <div className="bg-gradient-to-br from-blue-50 to-cyan-50 px-4 md:px-8 py-4 md:py-8 border-b-2 border-blue-200/60">
                          <div className="flex items-start gap-3 md:gap-6">
                            <img
                              src="https://ucarecdn.com/1d3af6f0-a64f-4a71-a100-414802839a19/-/format/auto/"
                              alt="Agent C"
                              className="w-20 h-20 md:w-32 md:h-32 object-contain flex-shrink-0 drop-shadow-lg"
                            />
                            <div className="flex-1">
                              <div className="text-base md:text-lg font-bold text-slate-900 mb-1">
                                Agent C
                              </div>
                              <div className="text-xs md:text-sm text-blue-700 font-semibold mb-2">
                                Logical AI Engineer
                              </div>
                              <div className="flex flex-wrap gap-1 md:gap-2">
                                <span className="text-xs px-2 md:px-3 py-1 bg-blue-100 text-blue-700 rounded-full font-medium">
                                  Systematic
                                </span>
                                <span className="text-xs px-2 md:px-3 py-1 bg-cyan-100 text-cyan-700 rounded-full font-medium">
                                  Data-Driven
                                </span>
                              </div>
                            </div>
                          </div>
                        </div>
                        <div className="px-4 md:px-8 py-4 md:py-8">
                          <p className="text-slate-700 leading-relaxed whitespace-pre-wrap text-sm md:text-[15px]">
                            {message.agentC}
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              )}
            </div>
          ))}

          {/* Enhanced Loading State - Responsive */}
          {loading && (
            <div className="space-y-8 md:space-y-12">
              <div className="flex items-center justify-center gap-2 md:gap-4 py-4">
                <div className="h-[2px] bg-gradient-to-r from-transparent via-indigo-300 to-transparent flex-1 max-w-xs"></div>
                <div className="flex items-center gap-2 md:gap-3 px-4 md:px-6 py-2 bg-gradient-to-r from-indigo-100 to-purple-100 rounded-full animate-pulse">
                  <div className="w-2 h-2 rounded-full bg-indigo-600 animate-pulse"></div>
                  <span className="text-xs md:text-sm font-bold text-indigo-900 uppercase tracking-[0.15em]">
                    Engineering Debate...
                  </span>
                </div>
                <div className="h-[2px] bg-gradient-to-r from-transparent via-purple-300 to-transparent flex-1 max-w-xs"></div>
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 md:gap-8">
                {/* Agent X Loading - Responsive */}
                <div className="relative">
                  <div className="absolute -inset-1 bg-gradient-to-br from-purple-400 via-pink-400 to-purple-500 rounded-2xl md:rounded-3xl opacity-30 blur-xl animate-pulse"></div>
                  <div className="relative bg-white border-2 border-purple-200/60 rounded-2xl md:rounded-3xl overflow-hidden shadow-xl">
                    <div className="bg-gradient-to-br from-purple-50 to-pink-50 px-4 md:px-8 py-4 md:py-8 border-b-2 border-purple-200/60">
                      <div className="flex items-start gap-3 md:gap-6">
                        <img
                          src="https://ucarecdn.com/82e21364-f8e6-4526-9464-16cac4cfaba6/-/format/auto/"
                          alt="Agent X"
                          className="w-20 h-20 md:w-32 md:h-32 object-contain flex-shrink-0 drop-shadow-lg"
                        />
                        <div className="flex-1">
                          <div className="text-base md:text-lg font-bold text-slate-900 mb-1">
                            Agent X
                          </div>
                          <div className="text-xs md:text-sm text-purple-700 font-semibold">
                            Innovating...
                          </div>
                        </div>
                      </div>
                    </div>
                    <div className="px-4 md:px-8 py-4 md:py-8">
                      <div className="space-y-3">
                        <div className="h-3 bg-gradient-to-r from-purple-200 via-purple-100 to-transparent rounded-full w-full animate-pulse"></div>
                        <div className="h-3 bg-gradient-to-r from-purple-200 via-purple-100 to-transparent rounded-full w-5/6 animate-pulse"></div>
                        <div className="h-3 bg-gradient-to-r from-purple-200 via-purple-100 to-transparent rounded-full w-4/6 animate-pulse"></div>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Agent C Loading - Responsive */}
                <div className="relative">
                  <div className="absolute -inset-1 bg-gradient-to-br from-blue-400 via-cyan-400 to-blue-500 rounded-2xl md:rounded-3xl opacity-30 blur-xl animate-pulse"></div>
                  <div className="relative bg-white border-2 border-blue-200/60 rounded-2xl md:rounded-3xl overflow-hidden shadow-xl">
                    <div className="bg-gradient-to-br from-blue-50 to-cyan-50 px-4 md:px-8 py-4 md:py-8 border-b-2 border-blue-200/60">
                      <div className="flex items-start gap-3 md:gap-6">
                        <img
                          src="https://ucarecdn.com/1d3af6f0-a64f-4a71-a100-414802839a19/-/format/auto/"
                          alt="Agent C"
                          className="w-20 h-20 md:w-32 md:h-32 object-contain flex-shrink-0 drop-shadow-lg"
                        />
                        <div className="flex-1">
                          <div className="text-base md:text-lg font-bold text-slate-900 mb-1">
                            Agent C
                          </div>
                          <div className="text-xs md:text-sm text-blue-700 font-semibold">
                            Analyzing...
                          </div>
                        </div>
                      </div>
                    </div>
                    <div className="px-4 md:px-8 py-4 md:py-8">
                      <div className="space-y-3">
                        <div className="h-3 bg-gradient-to-r from-blue-200 via-blue-100 to-transparent rounded-full w-full animate-pulse"></div>
                        <div className="h-3 bg-gradient-to-r from-blue-200 via-blue-100 to-transparent rounded-full w-5/6 animate-pulse"></div>
                        <div className="h-3 bg-gradient-to-r from-blue-200 via-blue-100 to-transparent rounded-full w-4/6 animate-pulse"></div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Enhanced Empty State - Responsive */}
          {conversation.length === 0 && !loading && (
            <div className="text-center py-12 md:py-20">
              <div className="flex flex-col md:flex-row items-center justify-center gap-8 md:gap-16 mb-8 md:mb-12">
                <div className="text-center">
                  <img
                    src="https://ucarecdn.com/82e21364-f8e6-4526-9464-16cac4cfaba6/-/format/auto/"
                    alt="Agent X"
                    className="w-32 h-32 md:w-48 md:h-48 object-contain mx-auto mb-3 drop-shadow-xl"
                  />
                </div>
                <div className="text-center">
                  <h1
                    className="text-3xl md:text-5xl mb-4 md:mb-8"
                    style={{
                      fontFamily:
                        '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
                      fontWeight: 100,
                    }}
                  >
                    <span style={{ fontWeight: 100 }}>Agent</span>
                    <span style={{ fontWeight: 300 }}>X</span>
                  </h1>
                  <p className="text-xs md:text-sm text-purple-600 font-semibold">
                    Creative Engineer
                  </p>
                  <div className="flex gap-1 justify-center mt-2">
                    <span className="text-xs px-2 py-1 bg-purple-100 text-purple-700 rounded-full">
                      Innovative
                    </span>
                  </div>
                </div>
              </div>

              <div className="text-slate-400 text-2xl md:text-4xl font-light mb-8 md:mb-12">
                vs
              </div>

              <div className="flex flex-col md:flex-row items-center justify-center gap-8 md:gap-16">
                <div className="text-center order-2 md:order-1">
                  <h1
                    className="text-3xl md:text-5xl mb-4 md:mb-8"
                    style={{
                      fontFamily:
                        '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
                      fontWeight: 100,
                    }}
                  >
                    <span style={{ fontWeight: 100 }}>Agent</span>
                    <span style={{ fontWeight: 300 }}>C</span>
                  </h1>
                  <p className="text-xs md:text-sm text-blue-600 font-semibold">
                    Logical Engineer
                  </p>
                  <div className="flex gap-1 justify-center mt-2">
                    <span className="text-xs px-2 py-1 bg-blue-100 text-blue-700 rounded-full">
                      Systematic
                    </span>
                  </div>
                </div>
                <div className="text-center order-1 md:order-2">
                  <img
                    src="https://ucarecdn.com/1d3af6f0-a64f-4a71-a100-414802839a19/-/format/auto/"
                    alt="Agent C"
                    className="w-32 h-32 md:w-48 md:h-48 object-contain mx-auto mb-3 drop-shadow-xl"
                  />
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Enhanced Error Display - Responsive */}
        {error && (
          <div className="mt-8 max-w-4xl mx-auto px-4">
            <div className="bg-red-50 border-l-4 border-red-500 text-red-700 px-4 md:px-8 py-4 md:py-5 rounded-2xl shadow-md">
              <div className="flex items-center gap-3">
                <div className="w-2 h-2 rounded-full bg-red-500"></div>
                <span className="font-semibold text-sm md:text-base">
                  {error}
                </span>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Enhanced Fixed Input - Responsive with Loop on bottom left */}
      <div className="fixed bottom-0 left-0 right-0 bg-white/90 backdrop-blur-2xl border-t-2 border-slate-200/60 shadow-2xl">
        <div className="max-w-6xl mx-auto px-4 md:px-8 py-4 md:py-8">
          <form onSubmit={handleSubmit} className="relative">
            <div className="relative group">
              <div className="absolute -inset-1 bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-600 rounded-2xl md:rounded-3xl opacity-0 group-hover:opacity-20 blur-xl transition-opacity duration-500"></div>
              <div className="relative flex gap-2 md:gap-4">
                <div className="flex-1 relative">
                  <input
                    type="text"
                    value={prompt}
                    onChange={(e) => setPrompt(e.target.value)}
                    placeholder="Enter a technical topic for both AI engineers to debate..."
                    className="w-full px-4 md:px-8 py-4 md:py-6 bg-white border-2 border-slate-300 rounded-2xl md:rounded-3xl focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent text-slate-900 placeholder-slate-400 shadow-lg text-sm md:text-base transition-all duration-300"
                    style={{
                      paddingBottom: showLoopButton ? "3.5rem" : undefined,
                    }}
                    disabled={loading}
                  />
                  {/* Loop button positioned at bottom left of input */}
                  {showLoopButton && (
                    <button
                      type="button"
                      onClick={handleLoop}
                      disabled={loading}
                      className="absolute bottom-3 left-3 md:left-4 bg-gradient-to-r from-purple-600 to-pink-600 text-white px-4 md:px-6 py-2 md:py-2.5 rounded-xl md:rounded-2xl font-bold text-xs md:text-sm hover:from-purple-700 hover:to-pink-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 flex items-center gap-2 shadow-lg hover:shadow-xl hover:scale-105 active:scale-95"
                    >
                      <svg
                        className="w-4 h-4"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                        />
                      </svg>
                      <span>Loop</span>
                    </button>
                  )}
                </div>
                <button
                  type="submit"
                  disabled={loading || !prompt.trim()}
                  className="bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-600 text-white px-6 md:px-12 py-4 md:py-6 rounded-2xl md:rounded-3xl font-bold hover:from-indigo-700 hover:via-purple-700 hover:to-pink-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 flex items-center gap-2 md:gap-3 shadow-xl hover:shadow-2xl hover:scale-105 active:scale-95"
                >
                  <Send className="w-4 h-4 md:w-5 md:h-5" />
                  <span className="hidden md:inline">Start Debate</span>
                  <span className="md:hidden">Start</span>
                </button>
              </div>
              {remaining !== null && (
                <div className="text-center mt-3">
                  <span className="text-xs md:text-sm text-slate-600">
                    {remaining} debate{remaining !== 1 ? "s" : ""} remaining
                    today
                  </span>
                </div>
              )}
            </div>
          </form>
        </div>
      </div>

      <style jsx global>{`
        html {
          scroll-behavior: smooth;
        }
        @keyframes pulse {
          0%, 100% {
            opacity: 1;
          }
          50% {
            opacity: 0.5;
          }
        }
        @keyframes float {
          0%, 100% {
            transform: translateY(0px);
          }
          50% {
            transform: translateY(-10px);
          }
        }
      `}</style>
    </div>
  );
}
