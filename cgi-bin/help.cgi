#!/usr/local/bin/perl
require CGI;
$cgi=new CGI;
$page=$ENV{'QUERY_STRING'};
if(!$page) {
$page=1;
}
print $cgi->header;
print<<MARK;
<html>
<head>
<title>
Help -- Page $page
</title>
</head>
<body link=red vlink=red alink=blue>
<table cellspacing=2.5>
<tr>
<td>
MARK


open(A,"help/menu.html");
@menu=<A>;
print "@menu\n</td>\n<td>";
open(B,"help/help$page.html") or print "Unknown help section!\n";
@page=<B>;
print @page;
print<<MARK;
</td>
</tr>
</table>
</body>
</html>
MARK


