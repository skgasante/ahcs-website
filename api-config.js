// AHCS Backend API URL
// After deploying to Railway, replace the URL below with your Railway deployment URL.
// Example: 'https://ahcs-backend-production.up.railway.app'
// Leave as localhost for local development.

const API_BASE_URL = ['localhost', '127.0.0.1'].includes(window.location.hostname)
	? 'http://localhost:3001'
	: 'https://ahcs-website-production.up.railway.app';
