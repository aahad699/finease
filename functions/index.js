/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

const ADMIN_EMAIL = "admin@finease.app";

function assertAdminRequest(data) {
  if (data.requestedByEmail !== ADMIN_EMAIL) {
    throw new Error("Only the FinEase admin account can run this action.");
  }
}

function userRecordToProfile(userRecord) {
  const providerIds = userRecord.providerData.map((provider) => provider.providerId);
  return {
    authUid: userRecord.uid,
    email: userRecord.email || "",
    fullName: userRecord.displayName || userRecord.email || "FinEase user",
    photoURL: userRecord.photoURL || "",
    phoneNumber: userRecord.phoneNumber || "",
    emailVerified: userRecord.emailVerified,
    authDisabled: userRecord.disabled,
    providerIds,
    role: userRecord.email === ADMIN_EMAIL ? "admin" : "user",
    accountStatus: userRecord.disabled ? "suspended" : "active",
    authCreatedAt: userRecord.metadata.creationTime || "",
    lastLoginAt: userRecord.metadata.lastSignInTime || "",
    authSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

exports.syncFirebaseAuthUsers = onDocumentCreated(
  "admin_user_sync_requests/{requestId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const request = snap.data();
    const db = admin.firestore();

    try {
      assertAdminRequest(request);
      await snap.ref.set({
        status: "running",
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      let nextPageToken;
      let synced = 0;
      do {
        const result = await admin.auth().listUsers(1000, nextPageToken);
        const batch = db.batch();
        for (const userRecord of result.users) {
          const userRef = db.collection("users").doc(userRecord.uid);
          batch.set(userRef, userRecordToProfile(userRecord), {merge: true});
          synced += 1;
        }
        await batch.commit();
        nextPageToken = result.pageToken;
      } while (nextPageToken);

      await snap.ref.set({
        status: "completed",
        synced,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    } catch (error) {
      await snap.ref.set({
        status: "failed",
        error: error.message,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  },
);

exports.processAdminUserAction = onDocumentCreated(
  "admin_user_actions/{actionId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const actionDoc = snap.data();
    const db = admin.firestore();
    const uid = actionDoc.uid;
    const action = actionDoc.action;
    const payload = actionDoc.payload || {};

    try {
      assertAdminRequest(actionDoc);
      if (!uid || typeof uid !== "string") {
        throw new Error("Missing Firebase Auth uid.");
      }

      await snap.ref.set({
        status: "running",
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      if (action === "disableAuth") {
        await admin.auth().updateUser(uid, {disabled: true});
        await db.collection("users").doc(uid).set({
          authDisabled: true,
          accountStatus: "suspended",
          authActionStatus: "completed",
          authActionCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      } else if (action === "enableAuth") {
        await admin.auth().updateUser(uid, {disabled: false});
        await db.collection("users").doc(uid).set({
          authDisabled: false,
          accountStatus: "active",
          authActionStatus: "completed",
          authActionCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      } else if (action === "setRole") {
        const role = payload.role === "admin" ? "admin" : payload.role === "demo" ? "demo" : "user";
        await admin.auth().setCustomUserClaims(uid, {role});
        await db.collection("users").doc(uid).set({
          role,
          customClaimsSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      } else if (action === "deleteAuth") {
        await admin.auth().deleteUser(uid);
        await db.collection("users").doc(uid).set({
          accountStatus: "deleted",
          authDeletedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      } else {
        throw new Error(`Unsupported admin action: ${action}`);
      }

      await snap.ref.set({
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    } catch (error) {
      await snap.ref.set({
        status: "failed",
        error: error.message,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      if (uid) {
        await db.collection("users").doc(uid).set({
          authActionStatus: "failed",
          authActionError: error.message,
          authActionCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    }
  },
);

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
