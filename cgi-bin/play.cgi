#!/usr/local/bin/perl
require CGI;
$cgi=new CGI;
print $cgi->header();
$opbullets=$cgi->param("opbullets");
$bullets=$cgi->param("bullets");
$bullets="0" if (! $bullets);
$opbullets="0" if(! $opbullets);
$win1=0;
$win2=0;
@todo=("Shoot","Load","Rebound","Sheild");
while(1) {
$random=int(rand(4));
if($cgi->param("opbullets") <= 0 && $todo[$random] eq "Shoot") {
redo;
} else {
last;
}
}
if($todo[$random] eq "Load") {
$opbullets=$opbullets+5;
}
if($cgi->param("shoot") && $bullets <= 0) {
$disabled="disabled=\"true\" ";
}
elsif($cgi->param("sheild") && $todo[$random] eq "Shoot") {
$message=$cgi->param("opponent") . " tries to shoot you, but you block it!";
$opbullets--;
} elsif($cgi->param("sheild") && $todo[$random] ne "Shoot") {
$message=$cgi->param("opponent") . " does a " . $todo[$random] . " and you sheild.";
} elsif($cgi->param("rebound") && $todo[$random] eq "Shoot") {
$message=$cgi->param("opponent") . " shoots, but you rebound and win!";
$win1=true;
$opbullets--; 
} elsif($cgi->param("rebound") && $todo[$random] ne "Shoot") {
$message="You rebound but that doesn't matter because " . $cgi->param("opponent") . " doesn't shoot.";
} elsif($cgi->param("load") && $todo[$random] eq "Shoot") {
$message="Ahh, don't you hate that? Your opponent shoots while you're reloading!";
$win2=true;
$opbullets--;
} elsif($cgi->param("load") && $todo[$random] ne "Shoot") {
$message="Reload! (by the way, " . $cgi->param("opponent") . " $todo[$random]s).";
$bullets=$bullets+5;
} elsif($cgi->param("shoot") && $todo[$random] eq "Shoot") {
$message="Ooop! You both shoot, anyway, on with the game.";
$opbullets--;
$bullets--;
} elsif($cgi->param("shoot") && $todo[$random] eq "Rebound") {
$message="Game over! Your bullet was rebounded!";
$win2=true;
$bullets--;
} elsif($cgi->param("shoot") && $todo[$random] eq "Sheild") {
$message="Ahh! " . $cgi->param("opponent") . " blocks you.";
$bullets--;
} elsif($cgi->param("shoot") && $todo[$random] eq "Load") {
$message="Yay! You got " . $cgi->param("opponent") . " while he was reloading!";
$bullets--;
$win1=true;
} else {
print "Unknown error!\n";
exit;
}
$move=$cgi->param("shoot") . $cgi->param("sheild") . $cgi->param("load") . $cgi->param("rebound");
$opponent=$cgi->param("opponent");
if($opbullets <= 0) {
$obcol="#FF0000";
} else {
$obcol="#00FF00";
}
if($bullets <= 0) {
$bcol="#FF0000";
} else {
$bcol="#00FF00";
}

print<<MARK;
<html>
<head>
<title>
ClapClap
</title>
<script>
function dis_Shoot() {
if(document.forms[0].bullets.value <= 0) {
document.forms[0].shoot.disabled=true;
} else {
document.forms[0].shoot.disabled=false;
}
}
</script>
</head>
<body onload="dis_Shoot();">
<center>
<table>
<tr>
<td>Your bullets:</td>
<td bgcolor="$bcol">
<font size=6 face=arial><b>$bullets</b></font>
</td>
<td>
${opponent}'s bullets:
</td>
<td bgcolor="$obcol">
<font size=6 face=arial><b>$opbullets</b></font>
</td>
</tr>
<tr>
<td colspan=4 align=center>
<b>ClapClap</b>
</td>
</tr>
<tr>
<td colspan=2 align=center>
You: $move
</td>
<td colspan=2 align=center>
$opponent: $todo[$random]
</td>
</tr>
<tr>
<td colspan=4 bgcolor=#ccffcc align=center>
$message
</td>
</tr>
</table>
<p>

MARK


if($win1) {
print "You win!<p><small><a href=\"index.cgi\">Play again!</a></body></html>\n";
} elsif($win2) {
print "$opponent wins!<p><small><a href=\"index.cgi\">Play again!</a></body></html>\n";
} else {
print<<MARK;

<form action=play.cgi method=post>
<input type=hidden name=opbullets value=$opbullets>
<input name=rounds value=1 type=hidden><input name=bullets value=$bullets type=hidden><input type=hidden name=opponent value="$opponent">
<input type=submit name=load value="Load"><input type=submit name=shoot value="Shoot"><input type=submit name=sheild value="Sheild"><input type=submit name=rebound value="Rebound">
</form>

MARK




}
