from flask import Flask, render_template, request
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)

# ✅ Attach Prometheus metrics
metrics = PrometheusMetrics(app, group_by="endpoint")


# ✅ Custom metric for tracking requests
metrics.info("frontend_service_info", "Frontend Service Metrics", version="1.0.0")

@app.route("/")
def homepage():
    return render_template("main.html")


if __name__ == "__main__":
    app.run()
