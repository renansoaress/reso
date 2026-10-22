"""Servidor HTTP do ReSo web: o http.server do Python com os cabecalhos certos.

    python3 tool/serve_web.py build/web --port 5500

- `application/wasm` para o .wasm (sem ele o navegador nao compila em fluxo);
- COOP/COEP: deixam a pagina isolada, e o motor WebAssembly usa varias
  threads;
- sem cache para index.html, sw.js e o bootstrap, para uma versao nova
  aparecer logo. O resto fica com o cache do service worker.

E o que o reso_web.service roda no servidor. Para instalar um PWA fora do
localhost o site precisa de HTTPS (o proxy na frente cuida disso).
"""

import argparse
import functools
import mimetypes
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("text/javascript", ".mjs")
mimetypes.add_type("application/manifest+json", ".webmanifest")

NO_CACHE = {"", "index.html", "sw.js", "flutter_bootstrap.js", "manifest.json"}


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("X-Content-Type-Options", "nosniff")
        name = self.path.split("?", 1)[0].rsplit("/", 1)[-1]
        if name in NO_CACHE:
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("directory", nargs="?", default="build/web")
    parser.add_argument("--port", type=int, default=5500)
    parser.add_argument("--bind", default="0.0.0.0")
    args = parser.parse_args()

    # O caminho e resolvido a cada pedido: trocar a pasta no deploy (mv) nao
    # exige reiniciar o servico.
    handler = functools.partial(Handler, directory=args.directory)
    with ThreadingHTTPServer((args.bind, args.port), handler) as server:
        print(f"ReSo web em http://{args.bind}:{args.port} ({args.directory})")
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
