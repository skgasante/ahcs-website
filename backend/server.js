const express = require('express');
const cors = require('cors');
const { supabase } = require('./supabase');
const fileUpload = require('express-fileupload');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Serve static files from the project root (one level up)
const path = require('path');
app.use(express.static(path.join(__dirname, '..')));

// Middleware
const allowedOrigins = [
  'https://ahcs-website.netlify.app',
  'https://skgasante.github.io',
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'http://localhost:5500',
  'http://127.0.0.1:5500',
  'http://localhost:3001',
  'http://127.0.0.1:3001',
];
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (e.g. curl, Postman) and allowed origins
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error(`CORS policy: origin ${origin} not allowed`));
    }
  },
}));

// Allow Chrome's Private Network Access preflight (file:// → localhost)
app.use((req, res, next) => {
  if (req.headers['access-control-request-private-network']) {
    res.setHeader('Access-Control-Allow-Private-Network', 'true');
  }
  next();
});

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(fileUpload({
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  abortOnLimit: true,
  responseOnLimit: JSON.stringify({ success: false, message: 'File too large. Maximum size is 5MB.' }),
}));

// Routes
app.use('/api/admissions', require('./routes/admissions'));
app.use('/api/jobs', require('./routes/jobs'));
app.use('/api/staff', require('./routes/staff'));
app.use('/api/reports', require('./routes/reports'));
app.use('/api/attendance', require('./routes/attendance'));
app.use('/api/admin/emergency', require('./routes/admin-emergency'));
app.use('/api/onboard', require('./routes/onboarding'));

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'AHCS Backend Server is running' });
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Error:', error);
  if (error.code === 'LIMIT_FILE_SIZE') {
    return res.status(400).json({
      success: false,
      message: 'File too large. Maximum size is 5MB.'
    });
  }
  res.status(500).json({
    success: false,
    message: 'Internal server error'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found'
  });
});

app.listen(PORT, () => {
  console.log(`🚀 AHCS Backend Server running on port ${PORT}`);
  console.log(`📊 Connected to Supabase: ${process.env.SUPABASE_URL}`);
});