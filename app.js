const dogs = [
 {id:1,name:"Max",breed:"Golden Retriever",place:"Ramat Gan Park",time:"12 min ago",photos:34,likes:128,spots:12,emoji:"🐕",tone:"c1"},
 {id:2,name:"Luna",breed:"French Bulldog",place:"City Garden",time:"28 min ago",photos:21,likes:96,spots:8,emoji:"🐶",tone:"c2"},
 {id:3,name:"Charlie",breed:"Beagle",place:"National Park",time:"1 hour ago",photos:18,likes:74,spots:6,emoji:"🦮",tone:"c3"}
];
let points = Number(localStorage.getItem("doggo-points") || 250);
let followed = new Set(JSON.parse(localStorage.getItem("doggo-following") || "[]"));
let currentDog = dogs[0];
let selectedPhoto = null;
const $ = s => document.querySelector(s);
const $$ = s => [...document.querySelectorAll(s)];
function toast(msg){const t=$("#toast");t.textContent=msg;t.classList.add("show");setTimeout(()=>t.classList.remove("show"),2400)}
function render(){
 $("#points").textContent=points;
 $("#recent-dogs").innerHTML=dogs.map(d=>`<article class="dog-card" data-dog="${d.id}"><div class="dog-photo ${d.tone}"><span class="photo-label">● ${d.time}</span>${d.emoji}</div><div class="dog-info"><h3>${d.name}</h3><p>${d.breed}</p><div class="dog-meta"><span>📍 ${d.place}</span><span>♡ ${d.likes}</span></div></div></article>`).join("");
 $("#top-dogs").innerHTML=[...dogs].sort((a,b)=>b.likes-a.likes).map((d,i)=>`<div class="leader-item"><span class="rank">0${i+1}</span><div class="leader-emoji">${d.emoji}</div><div class="leader-copy"><b>${d.name}</b><small>${d.breed}</small></div><span class="leader-score">♡ ${d.likes}</span></div>`).join("");
}
function openDog(d){currentDog=d;$("#detail-name").textContent=d.name;$("#detail-breed").textContent=d.breed+" · "+d.place;$("#detail-photos").textContent=d.photos;$("#detail-likes").textContent=d.likes;$("#detail-spots").textContent=d.spots;$("#detail-location").textContent=d.place+" · "+d.time;$("#detail-cover").textContent=d.emoji;$("#follow-dog").textContent=followed.has(d.id)?"✓ Following":"♡ Follow this dog";$("#dog-dialog").showModal()}
function setPage(page){
 $$(".nav-item").forEach(n=>n.classList.toggle("active",n.dataset.nav===page));
 if(page==="home"){location.hash="";$("#main-content").innerHTML=homeMarkup;render()}
 else if(page==="explore"){location.hash="explore";$("#main-content").innerHTML=exploreMarkup;renderExplore()}
 else if(page==="community"){location.hash="community";$("#main-content").innerHTML=communityMarkup;render()}
 else if(page==="profile"){location.hash="profile";$("#main-content").innerHTML=profileMarkup}
}
const homeMarkup=$("#main-content").innerHTML;
const exploreMarkup=`<section class="section"><span class="eyebrow">FIND YOUR NEXT HELLO</span><h2>Explore nearby dogs</h2><p class="muted">Discover dogs recently spotted by the community.</p><div class="discovery-banner"><div><h2>Map discovery</h2><p>Map integration will show approximate, recent sightings once connected to the location service.</p><button class="btn btn-dark" id="map-demo">Show sample sightings</button></div><div class="banner-emoji">🗺️</div></div><div class="section-heading"><h2>Nearby pack</h2></div><div class="dog-grid" id="recent-dogs"></div></section>`;
const communityMarkup=`<section class="section"><span class="eyebrow">THE PACK HAS SPOKEN</span><h2>Community leaderboard</h2><p class="muted">A friendly ranking of popular community dogs.</p><div class="leader-list" id="top-dogs"></div><div class="discovery-banner" style="margin-top:24px"><div><h2>Photo of the day</h2><p>Community voting and photo contests are next on the roadmap.</p></div><div class="banner-emoji">🏆</div></div></section>`;
const profileMarkup=`<section class="section"><span class="eyebrow">YOUR DOGGO ID</span><h2>Hey, Scout! 👋</h2><p class="muted">Your discoveries help every dog's story grow.</p><div class="discovery-banner"><div><h2 id="profile-points">${points} points</h2><p>Level 2 · Neighbourhood Explorer</p></div><div class="banner-emoji">🎖️</div></div><div class="stats-row"><div><b>12</b><span>dogs found</span></div><div><b>${followed.size}</b><span>following</span></div><div><b>8</b><span>photos added</span></div></div><h2>Your badges</h2><div class="leader-list"><div class="leader-item">🐾 First Scout</div><div class="leader-item">📸 Photo Pal</div><div class="leader-item">🧭 Explorer</div></div></section>`;
function renderExplore(){render();$("#map-demo")?.addEventListener("click",()=>toast("Mapbox integration is planned for the connected MVP."))}
$$("[data-nav]").forEach(b=>b.addEventListener("click",e=>{e.preventDefault();setPage(b.dataset.nav)}));
document.addEventListener("click",e=>{
 const nav=e.target.closest("[data-nav]");if(nav){e.preventDefault();setPage(nav.dataset.nav);return}
 const act=e.target.closest("[data-action]");if(act&&act.dataset.action==="scan"){$("#scan-dialog").showModal();return}
 const card=e.target.closest("[data-dog]");if(card){const d=dogs.find(x=>x.id===Number(card.dataset.dog));if(d)openDog(d);return}
 const close=e.target.closest("[data-close]");if(close)$("#"+close.dataset.close).close();
});
$("#dog-photo").addEventListener("change",e=>{const file=e.target.files[0];if(!file)return;selectedPhoto=file;const img=$("#photo-preview");img.src=URL.createObjectURL(file);img.classList.remove("hidden")});
$("#scan-form").addEventListener("submit",e=>{e.preventDefault();if(!selectedPhoto){toast("Choose a photo first");return}$("#scan-dialog").close();$("#match-dialog").showModal()});
$("#confirm-match").addEventListener("click",()=>{$("#match-dialog").close();$("#scan-dialog").close();points+=10;localStorage.setItem("doggo-points",points);render();toast("Demo sighting added to Max's story · +10 points")});
$("#new-dog").addEventListener("click",()=>{$("#match-dialog").close();$("#scan-dialog").close();toast("New dog profile creation will be enabled in the connected MVP.")});
$("#follow-dog").addEventListener("click",()=>{if(followed.has(currentDog.id))followed.delete(currentDog.id);else followed.add(currentDog.id);localStorage.setItem("doggo-following",JSON.stringify([...followed]));$("#follow-dog").textContent=followed.has(currentDog.id)?"✓ Following":"♡ Follow this dog";toast(followed.has(currentDog.id)?"Added to your pack":"Unfollowed dog")});
$("#add-album-photo").addEventListener("click",()=>{$("#dog-dialog").close();$("#scan-dialog").showModal();toast("Choose a photo to contribute to the community")});
$("#notifications").addEventListener("click",()=>toast("You're all caught up!"));
if("serviceWorker" in navigator)window.addEventListener("load",()=>navigator.serviceWorker.register("/sw.js").catch(()=>{}));
render();
