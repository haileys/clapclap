#!/usr/local/bin/perl
require CGI;

$cgi=new CGI;
while(1) {
@opponents=("Death Deluger","Mr. Fuzzy","The Boss","Ralphy");
$random=int(rand(4));
if($opponents[$random] eq $cgi->param("opponent")) {
redo;
} else {
last;
}
}


print $cgi->header();
print<<MARK;
<html>
<head>
<title>
ClapClap
</title>
</head>
<body>
UPDATED!<br>
There has been a security compromising bug on this website. It has now been fixed. Thankyou.
<center>
Your opponent is $opponents[$random].<br>
<small>Don't like $opponents[$random]? <a href="index.cgi?opponent=$opponents[$random]">Click here</a></small>
<p>
<form action=play.cgi method=post>
<input type=hidden name=opbullets value=0>
<input name=rounds value=1 type=hidden><input name=bullets value=0 type=hidden><input type=hidden name=opponent value="$opponents[$random]">
Choose a starting move:<br>
<input type=submit name=load value="Load"><input type=submit name=shoot value="Shoot" disabled=true><input type=submit name=sheild value="Sheild"><input type=submit name=rebound value="Rebound">
</form>
<a href="stats.cgi">View this computers stats</a> -- <b><font color=red>NEW!</font></b><br>
<a href="help.cgi?1">Help!</a>
</center>
</body>
</html>

MARK


