const express = require('express');
const cors = require('cors');
const { supabase } = require('./supabase');
const fileUpload = require('express-fileupload');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors({ origin: true }));

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
}));

// Routes
app.use('/api/admissions', require('./routes/admissions'));
app.use('/api/jobs', require('./routes/jobs'));

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