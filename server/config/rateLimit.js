// Express-rate-limit configuration for API rate limiting
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const windowMinutes = parseInt(process.env.RATE_LIMIT_WINDOW_MINUTES, 10) || 15;
const maxRequests = parseInt(process.env.RATE_LIMIT_MAX, 10) || 100;

// General rate limiter (configurable via env): max requests per window per IP
const apiLimiter = rateLimit({
    windowMs: windowMinutes * 60 * 1000, // window in minutes
    max: maxRequests,
    standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers
    message: {
        status: 429,
        message: 'Too many requests, please try again later.'
    }
});

module.exports = { apiLimiter };
