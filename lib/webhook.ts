type WebhookPayload = {
  playerName: string;
  displayName: string;
  userId: number;
  ip: string;
  key: string;
  keyType: string;
  hwid: string;
  executor: string;
  executorVersion: string;
  placeId: string;
  jobId: string;
};

const TYPE_LABEL: Record<string, string> = {
  day: "1 Day",
  week: "1 Week",
  month: "1 Month",
  lifetime: "Lifetime",
};

export async function sendExecutionWebhook(webhookUrl: string, p: WebhookPayload) {
  if (!webhookUrl) return;

  const joinUrl = `https://www.roblox.com/games/start?placeId=${p.placeId}&gameInstanceId=${p.jobId}`;
  const profileUrl = `https://www.roblox.com/users/${p.userId}/profile`;

  const body = {
    embeds: [
      {
        title: "Script Executed",
        color: 0x7c3aed,
        fields: [
          {
            name: "Player",
            value: `[${p.displayName !== p.playerName ? `${p.displayName} (@${p.playerName})` : `@${p.playerName}`}](${profileUrl})`,
            inline: true,
          },
          {
            name: "Executor",
            value: p.executorVersion ? `${p.executor} ${p.executorVersion}` : p.executor || "Unknown",
            inline: true,
          },
          {
            name: "IP",
            value: `\`${p.ip}\``,
            inline: true,
          },
          {
            name: "Key",
            value: `\`${p.key || "none"}\` — ${TYPE_LABEL[p.keyType] ?? p.keyType ?? "—"}`,
            inline: true,
          },
          {
            name: "HWID",
            value: `\`${p.hwid}\``,
            inline: false,
          },
          {
            name: "Join Server",
            value: `[Open in Roblox](${joinUrl})\n\`roblox://experiences/start?placeId=${p.placeId}&gameInstanceId=${p.jobId}\``,
            inline: false,
          },
        ],
        footer: { text: "juru.lol" },
        timestamp: new Date().toISOString(),
      },
    ],
  };

  try {
    await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch (e) {
    // Never let a failed webhook break the unlock flow.
    console.error("juru.lol webhook send failed:", e);
  }
}
