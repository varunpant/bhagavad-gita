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
onload = function(){
  bindAccordion();
}