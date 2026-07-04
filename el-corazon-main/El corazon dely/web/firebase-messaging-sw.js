importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDummyKeyForTesting",
  authDomain: "fastfoodgo-deliver.firebaseapp.com",
  projectId: "fastfoodgo-deliver",
  storageBucket: "fastfoodgo-deliver.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef123456"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle,
    notificationOptions);
});



