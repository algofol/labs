import http.server
import os
import resource
import uuid

# ── DEFECTIVE MODE (Option B - gradual cache leak) ────────────────────────────
# Uncomment the block below and remove the import comment to activate the leak.
# It simulates a cache that never evicts entries (~10KB per entry, 1000/sec).
# On a 512MB task it will OOM in ~30-45 minutes, producing a rising memory trend.
#
# import threading
#
# _cache = {}
#
# def _leak():
#     while True:
#         import time
#         for _ in range(1000):
#             _cache[str(uuid.uuid4())] = "x" * 10_000
#         print(f"[LEAK] cache entries: {len(_cache)}", flush=True)
#         time.sleep(1)
#
# threading.Thread(target=_leak, daemon=True).start()
# ─────────────────────────────────────────────────────────────────────────────


def get_memory_mb() -> float:
    """Return RSS memory usage of this process in MB."""
    usage = resource.getrusage(resource.RUSAGE_SELF)
    # ru_maxrss is in KB on Linux
    return usage.ru_maxrss / 1024


class AppHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        mem_mb = get_memory_mb()
        body = (
            f"Hi from ECS! I'm using {mem_mb:.2f} MB of memory\n"
        ).encode()

        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        mem_mb = get_memory_mb()
        print(
            f"[{self.log_date_time_string()}] {self.address_string()} "
            f"{format % args} | memory: {mem_mb:.2f} MB",
            flush=True,
        )


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    print(f"Starting server on port {port}", flush=True)
    server = http.server.HTTPServer(("0.0.0.0", port), AppHandler)
    server.serve_forever()
