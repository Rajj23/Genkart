require("dotenv").config();

const express = require("express");
const app = express();
const cors = require("cors");
const cookieParser = require("cookie-parser");
const bodyParser = require('body-parser')
const promClient = require("prom-client");

// Add rate limiting
const { apiLimiter } = require("./config/rateLimit");

const router = require("./routes/router");
const authRoutes = require("./routes/authRoutes");
const cartRoutes = require("./routes/cartRoutes");
const productRoutes = require("./routes/productRoutes");
const userRoutes = require("./routes/userRoutes")

require("./db/config");

promClient.collectDefaultMetrics();

const httpRequestDurationSeconds = new promClient.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.05, 0.1, 0.25, 0.5, 1, 2, 5],
});

// ── CORS ──────────────────────────────────────────────────────────────────────
// CLIENT_URL          → set in .env / K8s secret (e.g. http://genkart.com)
// EXTRA_CLIENT_URLS   → optional comma-separated list of additional origins
//                       (useful for staging, multiple domains, etc.)
// Localhost entries   → always allowed for local dev & Docker Compose
const PORT = process.env.PORT || 5555;
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(bodyParser.json());

// Trust the X-Forwarded-* headers from the nginx ingress
app.set("trust proxy", 1);

const staticOrigins = [
  "http://localhost:3005",
  "http://127.0.0.1:3005",
  "http://localhost:3001",
  "http://127.0.0.1:3001",
  "http://localhost:3000",
];

const envOrigins = [
  process.env.CLIENT_URL,
  ...(process.env.EXTRA_CLIENT_URLS
    ? process.env.EXTRA_CLIENT_URLS.split(",").map((u) => u.trim())
    : []),
];

const allowedOrigins = [...new Set([...staticOrigins, ...envOrigins])].filter(Boolean);

app.use(
  cors({
    origin(origin, callback) {
      // Allow server-to-server / curl / Postman (no Origin header)
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes(origin)) return callback(null, true);
      return callback(new Error(`Not allowed by CORS: ${origin}`));
    },
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "X-Requested-With",
      "Accept",
      "Origin",
    ],
    exposedHeaders: ["Set-Cookie"],
  })
);
// Handle pre-flight OPTIONS requests explicitly
app.options("*", cors());

app.use(cookieParser());

app.use((req, res, next) => {
  if (req.path === "/metrics") {
    return next();
  }

  const endTimer = httpRequestDurationSeconds.startTimer();

  res.on("finish", () => {
    endTimer({
      method: req.method,
      route: req.path,
      status_code: String(res.statusCode),
    });
  });

  next();
});

app.get("/metrics", async (req, res) => {
  res.set("Content-Type", promClient.register.contentType);
  res.end(await promClient.register.metrics());
});

// Health check – used by Docker healthcheck & K8s liveness/readiness probes
// Placed BEFORE the rate limiter so probes never get throttled
app.get("/api/health", (req, res) => {
  res.status(200).json({ status: "ok", timestamp: new Date().toISOString() });
});

// Apply rate limiting to all API routes (health check is exempt above)
app.use('/api', apiLimiter);

app.use('/', router);
app.use('/api/auth', authRoutes);
app.use('/auth', authRoutes);
app.use('/api/cart', cartRoutes);
app.use('/api/product', productRoutes);
app.use('/api/user', userRoutes);



// const allowCrossDomain = (req, res, next) => {
//   res.header(`Access-Control-Allow-Origin`, `*`);
//   res.header(`Access-Control-Allow-Methods`, `GET,PUT,POST,DELETE`);
//   res.header(`Access-Control-Allow-Headers`, `*`);
//   next();
// };
// app.use(allowCrossDomain);


// for parsing application/json
// app.use(bodyParser.urlencoded({ extended: true }))



app.listen(PORT, () => {
  console.log(`server running on http://localhost:${PORT}`);
});
