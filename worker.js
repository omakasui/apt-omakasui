/** Redirect APT pool paths to GitHub Release assets. */

const BUILD_REPO = "omakasui/build-apt-omakasui";

export default {
  async fetch(request) {
    const url = new URL(request.url);

    // Match legacy and namespaced pool paths.
    if (
      (request.method === "GET" || request.method === "HEAD") &&
      /^(?:\/[a-z0-9-]+)?\/pool\//.test(url.pathname)
    ) {
      const parts = url.pathname.split("/").filter(Boolean);
      const poolIndex = parts.indexOf("pool");
      if (poolIndex >= 0 && parts.length === poolIndex + 3) {
        const tag = parts[poolIndex + 1];
        const filename = parts[poolIndex + 2];
        const target = `https://github.com/${BUILD_REPO}/releases/download/${tag}/${filename}`;
        return Response.redirect(target, 302);
      }
    }

    // Serve repository metadata from GitHub Pages.
    return fetch(request);
  },
};
