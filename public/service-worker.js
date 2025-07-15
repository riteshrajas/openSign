self.addEventListener('install', () => {
  console.log('OpenSeal App installed')
})

self.addEventListener('activate', () => {
  console.log('OpenSeal App activated')
})

self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request))
})
