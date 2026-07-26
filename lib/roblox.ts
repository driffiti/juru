// Roblox's HttpService / every executor's request function sends a
// User-Agent containing "Roblox". Ordinary browsers never do.
export function isRobloxClient(userAgent: string | null): boolean {
  if (!userAgent) return false;
  return /roblox/i.test(userAgent);
}
