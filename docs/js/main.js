function toggleNav(ele) {
  var w = document.getElementById("sidenav").style.width;
  console.log(w)
  if (w == "0px" || w == "" || !w) {
    openNav();
  } else {
    closeNav();
  }
}

function openNav() {
  document.getElementById("sidenav").style.width = "150px";
  document.getElementById("content").style.marginLeft = "150px";
  document.getElementById("burger").style.display = "none";
}

/* Set the width of the side navigation to 0 */
function closeNav() {
  document.getElementById("sidenav").style.width = "0";
  document.getElementById("content").style.marginLeft = "auto";
  document.getElementById("burger").style.display = "";
}

var bindAccordion = function(){
  var acc = document.getElementsByClassName("accordion");
var i;

for (i = 0; i < acc.length; i++) {
  acc[i].addEventListener("click", function() {
   
    this.classList.toggle("active");

    /* Toggle between hiding and showing the active panel */
    var panel = this.nextElementSibling;
    if (panel.style.display === "block") {
      panel.style.display = "none";
    } else {
      panel.style.display = "block";
    }
  });
}

}


var getParams = function(navlink){
  var l = document.createElement("a");
  l.href = navlink;
  try{
    var chapter = l.pathname.match(/chapter-(\d+)*/,"")[1];
    var sutra = l.pathname.match(/sutra-(\d+)*/,"")[1];
    return {
      "c":chapter,
      "s":sutra,
      "h":l.hostname
    }
  }
  catch{
    return null,null,l.hostname;
  }
 
}

var preopenAccordion = function(chapter){
  var ac = document.getElementById("btn"+chapter);
  if(ac){ac.click()};
}
var initAppState = function(){
  var KEY = "VERSE"
  if (localStorage){

    window.onbeforeunload = function () {
      var navlink = document.activeElement.href;
      if(navlink){
        var params = getParams(navlink);
        var chapter = params.c;
        var sutra = params.s;
        var hostname = params.h;
       
        if(hostname === window.location.hostname){
           if(!isNaN(chapter) && !isNaN(sutra)){
            var verse = chapter + "," + sutra;
            localStorage[KEY] = verse;
            console.log("state saved"+verse)
           }
        }
      } 
  };


    var state = localStorage[KEY] ;
    if(state){
              var verse = state.split(",");
              var chapter = verse[0];
              var sutra = verse[1];
              var params = getParams(window.location.href);
              var _chapter = params.c;
              var _sutra = params.s;
              preopenAccordion(_chapter);
              if(!_chapter && !_sutra){
                var url = location.protocol + "//" + window.location.host + "/chapter-" + chapter + "/sutra-" +sutra;
                location.assign(url);
              }
             
    }else{
      console.log("previous state not found.")
    }
  }
  else{
    console.log("Localstorage not supported.")
  }
 
}

onload = function(){
  bindAccordion();
  initAppState();
}