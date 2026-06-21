import { initializeApp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-app.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";
import { getAuth, GoogleAuthProvider } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-auth.js";

const firebaseConfig = {
  apiKey: "AIzaSyAxDJ_NURHYY-8u59RmugKoSAOL1KcgzSA",
  authDomain: "vibeboutique-ce4ad.firebaseapp.com",
  projectId: "vibeboutique-ce4ad",
  storageBucket: "vibeboutique-ce4ad.firebasestorage.app",
  messagingSenderId: "932462174985",
  appId: "1:932462174985:web:1682c0afbb08f8b44c69d8",
  measurementId: "G-EDMK8YXQVV"
};

// isConfigured = true when the key is NOT the placeholder "YOUR_API_KEY"
// Since you have filled in your real key, this will correctly be true
const isConfigured = firebaseConfig.apiKey !== "YOUR_API_KEY";

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);
const auth = getAuth(app);

// Google Sign-In provider — needed by auth.js and main.js
const googleProvider = new GoogleAuthProvider();

export { app, db, auth, googleProvider, isConfigured };
