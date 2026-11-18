import { localDev, placeholderAuth, vercelOidc } from "eve/channels/auth";
import { eveChannel } from "eve/channels/eve";

const authenticateLocalDev = localDev();

export default eveChannel({
  auth: [
    // Lets the eve TUI and your Vercel deployments reach the deployed agent.
    vercelOidc(),
    // Open on localhost for `eve dev` / evals; grant tool stubs for local eval runners only.
    async (request) => {
      const caller = await authenticateLocalDev(request);
      return caller ? { ...caller, allowToolStubs: true } : null;
    },
    // This placeholder will not allow browser requests in production.
    // Replace it with your app's auth provider, like Auth.js or Clerk,
    // or use none() for a public demo.
    placeholderAuth(),
  ],
});
