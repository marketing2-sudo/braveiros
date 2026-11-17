self.addEventListener('install',()=>self.skipWaiting());self.addEventListener('activate',e=>e.waitUntil(self.clients.claim()));
self.addEventListener('push',e=>{let d={};try{d=e.data.json()}catch{}e.waitUntil(self.registration.showNotification(d.title||'Braveiros',{body:d.body||'Há uma novidade no portal.',icon:'/icon-192.png',tag:d.tag, data:{url:'/'}}))});
self.addEventListener('notificationclick',e=>{e.notification.close();e.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(cs=>cs.length?cs[0].focus():self.clients.openWindow('/')))});
