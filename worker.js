/** Redirect APT pool paths to GitHub Release assets. */

const BUILD_REPO = "omakasui/build-apt-omakasui";
const KEYRING = "omakasui-core-archive-keyring";
const PRODUCTS = ["omabuntu", "omadeb"];

// Resolve the pool path of `pkg` from a Packages index, or null.
async function poolPath(origin, index, pkg) {
  const res = await fetch(`${origin}${index}`, { cf: { cacheTtl: 300 } });
  if (!res.ok) return null;
  const stanza = (await res.text())
    .split("\n\n")
    .find((s) => s.startsWith(`Package: ${pkg}\n`));
  return stanza?.match(/^Filename: (pool\/[^\n]+)$/m)?.[1] ?? null;
}

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const isRead = request.method === "GET" || request.method === "HEAD";

    // Stable bootstrap URL: /omakasui-core-archive-keyring/<suite>.deb, looked
    // up in the product that publishes the suite.
    const keyring = url.pathname.match(new RegExp(`^/${KEYRING}/([a-z]+)\\.deb$`));
    if (isRead && keyring) {
      let path = null;
      for (const product of PRODUCTS) {
        path = await poolPath(
          url.origin, `/${product}/dists/${keyring[1]}/main/binary-amd64/Packages`, KEYRING);
        if (path) break;
      }
      if (!path) return new Response("Not found\n", { status: 404 });
      url.pathname = `/${path}`;
    }

    // Match legacy and namespaced pool paths.
    if (isRead && /^(?:\/[a-z0-9-]+)?\/pool\//.test(url.pathname)) {
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
