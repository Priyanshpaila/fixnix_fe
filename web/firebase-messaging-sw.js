/* eslint-disable no-undef */
// Firebase v9+ compat SW for FlutterFire messaging
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js');

// These values will be injected by flutterfire configure in index.html, but
// if you prefer hardcoding, paste your web config here:
firebase.initializeApp({
  apiKey: "AIzaSyAc4QJP35quSRwdtZnj9QlSr5AFU_-jmbc",
  authDomain: "ticketapp-56785.firebaseapp.com",
  projectId: "ticketapp-56785",
  storageBucket: "ticketapp-56785.appspot.com",
  messagingSenderId: "129673915555",
  appId: "1:129673915555:android:9a14c45cb410e4ce1ca316",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  // Optional: show a notification
  const title = payload?.notification?.title || 'New ticket';
  const options = {
    body: payload?.notification?.body || '',
    data: payload?.data || {},
  };
  self.registration.showNotification(title, options);
});
