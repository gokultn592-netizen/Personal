import {
  signInWithPopup,
  signOut,
  onAuthStateChanged
} from "https://www.gstatic.com/firebasejs/10.8.0/firebase-auth.js";
import { doc, getDoc, getDocFromServer, setDoc, serverTimestamp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";
import { auth, googleProvider, db, isConfigured } from "./firebase-config.js";

// ─────────────────────────────────────────────
// ROLE CACHE
// ─────────────────────────────────────────────
// We do NOT persist the role in sessionStorage/localStorage.
// Reason: if an admin is promoted/demoted in Firestore, the change
// must take effect on the next page load without requiring sign-out.
// To avoid redundant Firestore reads within the same page load,
// we cache the resolved role directly on the user object as `user.role`.
let _cachedUser = null;

// ─────────────────────────────────────────────
// SIGN IN WITH GOOGLE
// ─────────────────────────────────────────────
export async function signInWithGoogle() {
  if (!isConfigured) {
    // Demo mode: simulate a buyer login
    sessionStorage.setItem("boutique_demo_user", JSON.stringify({
      uid: "demo-buyer-001",
      displayName: "Demo Buyer",
      email: "buyer@demo.com",
      photoURL: null
    }));
    window.location.reload();
    return;
  }

  try {
    const result = await signInWithPopup(auth, googleProvider);
    // Save/update user profile in Firestore right after sign-in
    await saveUserToFirestore(result.user);
    // Reload page to run the boot sequence for the authenticated user
    window.location.reload();
    return result.user;
  } catch (error) {
    console.error("Google Sign-In failed:", error);
    throw error;
  }
}

// ─────────────────────────────────────────────
// SIGN OUT
// ─────────────────────────────────────────────
export async function signOutUser() {
  sessionStorage.removeItem("boutique_demo_user");
  _cachedUser = null;

  if (!isConfigured) {
    window.location.reload();
    return;
  }

  try {
    await signOut(auth);
  } catch (error) {
    console.error("Sign-out failed:", error);
  }
  window.location.reload();
}

// ─────────────────────────────────────────────
// GET CURRENT USER
// Returns: Firebase user object (or demo object), or null if not signed in
// ─────────────────────────────────────────────
export function getCurrentUser() {
  if (!isConfigured) {
    const stored = sessionStorage.getItem("boutique_demo_user");
    return stored ? JSON.parse(stored) : null;
  }
  return auth.currentUser || _cachedUser;
}

// ─────────────────────────────────────────────
// RESOLVE ROLE
// Checks Firestore "users" document for role field first.
// Fallback: checks "admins" collection for UID.
// Returns: "admin" | "buyer"
// ─────────────────────────────────────────────
export async function resolveRole(user) {
  if (!user) return null;

  // Use the role cached on the user object if already resolved during this page load
  if (user.role) return user.role;

  if (!isConfigured) {
    const role = user.uid === "demo-admin-001" ? "admin" : "buyer";
    user.role = role;
    return role;
  }

  try {
    // getDocFromServer bypasses Firestore's local offline cache.
    // This guarantees we always read the LATEST role from Firebase.
    
    // 1. Try to read from the users collection first
    const userDoc = await getDocFromServer(doc(db, "users", user.uid));
    if (userDoc.exists()) {
      const data = userDoc.data();
      if (data && data.role) {
        user.role = data.role;
        return data.role;
      }
    }

    // 2. Fallback: check the admins collection
    const adminDoc = await getDocFromServer(doc(db, "admins", user.uid));
    const role = adminDoc.exists() ? "admin" : "buyer";
    user.role = role;
    return role;
  } catch (error) {
    console.error("Role check failed:", error);
    return "buyer";
  }
}

// ─────────────────────────────────────────────
// SAVE USER TO FIRESTORE
// Called on every sign-in — creates the user doc if new,
// or updates lastSignIn + name/photo if returning user.
// Firestore uses merge:true so existing fields are not erased.
// ─────────────────────────────────────────────
export async function saveUserToFirestore(user) {
  if (!user || !isConfigured) return;

  try {
    const role = await resolveRole(user); // "admin" or "buyer"
    const userRef = doc(db, "users", user.uid);

    await setDoc(userRef, {
      uid:         user.uid,
      displayName: user.displayName  || "",
      email:       user.email        || "",
      photoURL:    user.photoURL     || "",
      role:        role,
      lastSignIn:  serverTimestamp(),
      // createdAt is only written the very first time (merge keeps the old value after that)
      createdAt:   serverTimestamp()
    }, { merge: true });

    console.log(`User saved to Firestore: ${user.email} (${role})`);
  } catch (error) {
    // Non-fatal — the site still works even if the write fails
    console.warn("Could not save user profile to Firestore:", error);
  }
}

// ─────────────────────────────────────────────
// WAIT FOR AUTH STATE  (promise-based, one-shot)
// Used by pages that need to know the user before rendering
// ─────────────────────────────────────────────
export function waitForAuthState() {
  return new Promise((resolve) => {
    if (!isConfigured) {
      const demoUser = sessionStorage.getItem("boutique_demo_user");
      resolve(demoUser ? JSON.parse(demoUser) : null);
      return;
    }

    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      unsubscribe(); // stop listening after first result
      _cachedUser = user;
      // Refresh the user's Firestore record on every page load while signed in
      if (user) await saveUserToFirestore(user);
      resolve(user);
    });
  });
}

// ─────────────────────────────────────────────
// ADMIN GUARD
// Call this at the top of any admin page.
// If user is not an admin → redirects to home.
// ─────────────────────────────────────────────
export async function requireAdmin() {
  const user = await waitForAuthState();

  if (!user) {
    // Not signed in at all → go to home (sign-in overlay will appear)
    window.location.href = "../index.html";
    return null;
  }

  const role = await resolveRole(user);

  if (role !== "admin") {
    // Signed in but not admin → send buyers back to home
    window.location.href = "../index.html";
    return null;
  }

  return { user, role };
}
