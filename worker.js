/**
 * Cloudflare Worker — pool redirect for omakasui-packages.omakasui.org
 *
 * apt always treats the Filename field in a Packages index as a path relative
 * to the repository base URL.  Binary packages live as release assets in
 * omakasui/build-apt-omakasui, so we need a redirect layer instead of
 * storing .deb files in this repository.
 *
 * Filename written to Packages:  pool/<tag>/<file>
 * Worker redirects:               /pool/<tag>/<file>
 *   → https://github.com/omakasui/build-apt-omakasui/releases/download/<tag>/<file>
 *
 * apt follows HTTP 302 redirects, so the download ends up at the GitHub CDN
 * without any binary ever being committed to this repo.
 *
 * Every other request is passed through to GitHub Pages unchanged.
 */

const BUILD_REPO = "omakasui/build-apt-omakasui";

export default {
  async fetch(request) {
    const url = new URL(request.url);

    // Only intercept GET/HEAD requests to /pool/<tag>/<filename>
    if (
      (request.method === "GET" || request.method === "HEAD") &&
      url.pathname.startsWith("/pool/")
    ) {
      const parts = url.pathname.split("/").filter(Boolean);
      // Expect exactly: ['pool', '<tag>', '<filename>']
      if (parts.length === 3) {
        const [, tag, filename] = parts;
        const target = `https://github.com/${BUILD_REPO}/releases/download/${encodeURIComponent(tag)}/${encodeURIComponent(filename)}`;
        return Response.redirect(target, 302);
      }
    }

    // Pass everything else through to GitHub Pages.
    return fetch(request);
  },
};
