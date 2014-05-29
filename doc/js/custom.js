//custom javascript code
////Author: Yunfei Guo
////Copyright 2014

var table_of_content=
"<nav role='navigation' class='table-of-contents'>"+
"<h2>On this page:</h2>"+
"<ul>";

$("#templatemo_main h3").each(function() 
	{
	    var el,title,link;
	    el=$(this);
	    title=el.text();
	    link="#"+el.attr("id");

	    newline="<li>"+"<a href='"+link+"'>"+title+"</a>"+"</li>";
	    table_of_content += newline;
	});
table_of_content+="</ul>"+"</nav>";
$("#table-of-content").prepend(table_of_content);
