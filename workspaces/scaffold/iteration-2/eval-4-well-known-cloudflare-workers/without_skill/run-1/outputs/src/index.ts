export interface Env {
  ENVIRONMENT: string;
  /** Config value sourced from AWS at build/deploy time. */
  APP_CONFIG?: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return Response.json({ status: "ok", environment: env.ENVIRONMENT });
    }

    return new Response("Hello from Cloudflare Workers!", {
      headers: { "content-type": "text/plain" },
    });
  },
} satisfies ExportedHandler<Env>;
