package CGI;
require 5.001;
$AUTOLOAD_DEBUG=0;
$NPH=0;
$CGI::revision = '$Id: CGI.pm,v 2.30 1997/1/01 12:12 lstein Exp $';
$CGI::VERSION='2.30';
unless ($OS) {
    unless ($OS = $^O) {
	require Config;
	$OS = $Config::Config{'osname'};
    }
}
if ($OS=~/Win/i) {
    $OS = 'WINDOWS';
} elsif ($OS=~/vms/i) {
    $OS = 'VMS';
} elsif ($OS=~/Mac/i) {
    $OS = 'MACINTOSH';
} else {
    $OS = 'UNIX';
}
$needs_binmode = $OS=~/^(WINDOWS|VMS)/;
$DefaultClass = 'CGI' unless defined $CGI::DefaultClass;
$SL = {
    UNIX=>'/',
    WINDOWS=>'\\',
    MACINTOSH=>':',
    VMS=>'\\'
    }->{$OS};
$NPH++ if $ENV{'SERVER_SOFTWARE'}=~/IIS/;
$CRLF = "\015\012";
if ($needs_binmode) {
    $CGI::DefaultClass->binmode(main::STDOUT);
    $CGI::DefaultClass->binmode(main::STDIN);
    $CGI::DefaultClass->binmode(main::STDERR);
}
%OVERLOAD = ('""'=>'as_string');
%EXPORT_TAGS = (
	      ':html2'=>[h1..h6,qw/p br hr ol ul li dl dt dd menu code var strong em
			 tt i b blockquote pre img a address cite samp dfn html head
			 base body link nextid title meta kbd start_html end_html
			 input Select option/],
	      ':html3'=>[qw/div table caption th td TR Tr super sub strike applet PARAM embed basefont/],
	      ':netscape'=>[qw/blink frameset frame script font fontsize center/],
	      ':form'=>[qw/textfield textarea filefield password_field hidden checkbox checkbox_group 
		       submit reset defaults radio_group popup_menu button autoEscape
		       scrolling_list image_button start_form end_form startform endform
		       start_multipart_form isindex tmpFileName URL_ENCODED MULTIPART/],
	      ':cgi'=>[qw/param path_info path_translated url self_url script_name cookie 
		       raw_cookie request_method query_string accept user_agent remote_host 
		       remote_addr referer server_name server_software server_port server_protocol
		       virtual_host remote_ident auth_type http
		       remote_user user_name header redirect import_names put/],
	      ':ssl' => [qw/https/],
	      ':cgi-lib' => [qw/ReadParse PrintHeader HtmlTop HtmlBot SplitParam/],
	      ':html' => [qw/:html2 :html3 :netscape/],
	      ':standard' => [qw/:html2 :form :cgi/],
	      ':all' => [qw/:html2 :html3 :netscape :form :cgi/]
	 );
sub import {
    my $self = shift;
    my ($callpack, $callfile, $callline) = caller;
    foreach (@_) {
	$NPH++, next if $_ eq ':nph';
	foreach (&expand_tags($_)) {
	    tr/a-zA-Z0-9_//cd;  
	    $EXPORT{$_}++;
	}
    }
    my @packages = ($self,@{"$self\:\:ISA"});
    foreach $sym (keys %EXPORT) {
	my $pck;
	my $def = $DefaultClass;
	foreach $pck (@packages) {
	    if (defined(&{"$pck\:\:$sym"})) {
		$def = $pck;
		last;
	    }
	}
	*{"${callpack}::$sym"} = \&{"$def\:\:$sym"};
    }
}
sub expand_tags {
    my($tag) = @_;
    my(@r);
    return ($tag) unless $EXPORT_TAGS{$tag};
    foreach (@{$EXPORT_TAGS{$tag}}) {
	push(@r,&expand_tags($_));
    }
    return @r;
}
sub new {
    my($class,$initializer) = @_;
    my $self = {};
    bless $self,ref $class || $class || $DefaultClass;
    $initializer = to_filehandle($initializer) if $initializer;
    $self->init($initializer);
    return $self;
}
sub DESTROY { }
sub param {
    my($self,@p) = self_or_default(@_);
    return $self->all_parameters unless @p;
    my($name,$value,@other);
    if (@p > 1) {
	($name,$value,@other) = $self->rearrange([NAME,[DEFAULT,VALUE,VALUES]],@p);
	my(@values);
	if (substr($p[0],0,1) eq '-' || $self->use_named_parameters) {
	    @values = defined($value) ? (ref($value) && ref($value) eq 'ARRAY' ? @{$value} : $value) : ();
	} else {
	    foreach ($value,@other) {
		push(@values,$_) if defined($_);
	    }
	}
	if (@values) {
	    $self->add_parameter($name);
	    $self->{$name}=[@values];
	}
    } else {
	$name = $p[0];
    }
    return () unless defined($name) && $self->{$name};
    return wantarray ? @{$self->{$name}} : $self->{$name}->[0];
}
sub delete {
    my($self,$name) = self_or_default(@_);
    delete $self->{$name};
    delete $self->{'.fieldnames'}->{$name};
    @{$self->{'.parameters'}}=grep($_ ne $name,$self->param());
    return wantarray ? () : undef;
}
sub self_or_default {
    return @_ if defined($_[0]) && !ref($_[0]) && ($_[0] eq 'CGI');
    unless (defined($_[0]) && 
	    ref($_[0]) &&
	    (ref($_[0]) eq 'CGI' ||
	     eval "\$_[0]->isaCGI()")) { 
	$Q = $CGI::DefaultClass->new unless defined($Q);
	unshift(@_,$Q);
    }
    return @_;
}
sub self_or_CGI {
    local $^W=0;                
    if (defined($_[0]) &&
	(substr(ref($_[0]),0,3) eq 'CGI' 
	 || eval "\$_[0]->isaCGI()")) {
	return @_;
    } else {
	return ($DefaultClass,@_);
    }
}
sub isaCGI {
    return 1;
}
sub import_names {
    my($self,$namespace) = self_or_default(@_);
    $namespace = 'Q' unless defined($namespace);
    die "Can't import names into 'main'\n"
	if $namespace eq 'main';
    my($param,@value,$var);
    foreach $param ($self->param) {
	($var = $param)=~tr/a-zA-Z0-9_/_/c;
	$var = "${namespace}::$var";
	@value = $self->param($param);
	@{$var} = @value;
	${$var} = $value[0];
    }
}
sub use_named_parameters {
    my($self,$use_named) = self_or_default(@_);
    return $self->{'.named'} unless defined ($use_named);
    return $self->{'.named'}=$use_named;
}
sub init {
    my($self,$initializer) = @_;
    my($query_string,@lines);
    my($meth) = '';
    if (defined(@QUERY_PARAM) && !defined($initializer)) {
	foreach (@QUERY_PARAM) {
	    $self->param('-name'=>$_,'-value'=>$QUERY_PARAM{$_});
	}
	return;
    }
    $meth=$ENV{'REQUEST_METHOD'} if defined($ENV{'REQUEST_METHOD'});
  METHOD: {
      if (defined($initializer)) {
	  if (ref($initializer) && ref($initializer) eq 'HASH') {
	      foreach (keys %$initializer) {
		  $self->param('-name'=>$_,'-value'=>$initializer->{$_});
	      }
	      last METHOD;
	  }
	  $initializer = $$initializer if ref($initializer);
	  if (defined(fileno($initializer))) {
	      while (<$initializer>) {
		  chomp;
		  last if /^=/;
		  push(@lines,$_);
	      }
	      if ("@lines" =~ /=/) {
		  $query_string=join("&",@lines);
	      } else {
		  $query_string=join("+",@lines);
	      }
	      last METHOD;
	  }
	  $query_string = $initializer;
	  last METHOD;
      }
      if ($meth=~/^(GET|HEAD)$/) {
	$query_string = $ENV{'QUERY_STRING'};
	last METHOD;
    }
      if ($meth eq 'POST') {
	  if ($ENV{'CONTENT_TYPE'}=~m|^multipart/form-data|) {
	      my($boundary) = $ENV{'CONTENT_TYPE'}=~/boundary=(\S+)/;
	      $self->read_multipart($boundary,$ENV{'CONTENT_LENGTH'});
	  } else {
	      $self->read_from_client(\*STDIN,\$query_string,$ENV{'CONTENT_LENGTH'},0)
		  if $ENV{'CONTENT_LENGTH'} > 0;
	  }
	  last METHOD;
      }
      $query_string = &read_from_cmdline;
  }
    if ($query_string) {
	if ($query_string =~ /=/) {
	    $self->parse_params($query_string);
	} else {
	    $self->add_parameter('keywords');
	    $self->{'keywords'} = [$self->parse_keywordlist($query_string)];
	}
    }
    if ($self->param('.defaults')) {
	undef %{$self};
    }
    $self->{'.fieldnames'} = {};
    foreach ($self->param('.cgifields')) {
	$self->{'.fieldnames'}->{$_}++;
    }
    $self->delete('.submit');
    $self->delete('.cgifields');
    $self->save_request unless $initializer;
}
sub to_filehandle {
    my $string = shift;
    if ($string && !ref($string)) {
	my($package) = caller(1);
	my($tmp) = $string=~/[':]/ ? $string : "$package\:\:$string"; 
	return $tmp if defined(fileno($tmp));
    }
    return $string;
}
sub new_MultipartBuffer {
    my($self,$boundary,$length,$filehandle) = @_;
    return MultipartBuffer->new($self,$boundary,$length,$filehandle);
}
sub read_from_client {
    my($self, $fh, $buff, $len, $offset) = @_;
    local $^W=0;                
    return read($fh, $$buff, $len, $offset);
}
sub binmode {
    binmode($_[1]);
}
sub put {
    my($self,@p) = self_or_default(@_);
    $self->print(@p);
}
sub print {
    shift;
    CORE::print(@_);
}
sub unescape {
    my($todecode) = @_;
    $todecode =~ tr/+/ /;       
    $todecode =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
    return $todecode;
}
sub escape {
    my($toencode) = @_;
    $toencode=~s/([^a-zA-Z0-9_\-.])/uc sprintf("%%%02x",ord($1))/eg;
    return $toencode;
}
sub save_request {
    my($self) = @_;
    @QUERY_PARAM = $self->param; 
    foreach (@QUERY_PARAM) {
	$QUERY_PARAM{$_}=$self->{$_};
    }
}
sub parse_keywordlist {
    my($self,$tosplit) = @_;
    $tosplit = &unescape($tosplit); 
    $tosplit=~tr/+/ /;          
    my(@keywords) = split(/\s+/,$tosplit);
    return @keywords;
}
sub parse_params {
    my($self,$tosplit) = @_;
    my(@pairs) = split('&',$tosplit);
    my($param,$value);
    foreach (@pairs) {
	($param,$value) = split('=');
	$param = &unescape($param);
	$value = &unescape($value);
	$self->add_parameter($param);
	push (@{$self->{$param}},$value);
    }
}
sub add_parameter {
    my($self,$param)=@_;
    push (@{$self->{'.parameters'}},$param) 
	unless defined($self->{$param});
}
sub all_parameters {
    my $self = shift;
    return () unless defined($self) && $self->{'.parameters'};
    return () unless @{$self->{'.parameters'}};
    return @{$self->{'.parameters'}};
}
sub as_string {
    &dump(@_);
}
AUTOLOAD {
    print STDERR "CGI::AUTOLOAD for $AUTOLOAD\n" if $CGI::AUTOLOAD_DEBUG;
    my($func) = $AUTOLOAD;
    my($pack,$func_name) = $func=~/(.+)::([^:]+)$/;
    $pack = $CGI::DefaultClass
	unless defined(${"$pack\:\:AUTOLOADED_ROUTINES"});
    my($sub) = \%{"$pack\:\:SUBS"};
    unless (%$sub) {
	my($auto) = \${"$pack\:\:AUTOLOADED_ROUTINES"};
	eval "package $pack; $$auto";
	die $@ if $@;
    }
    my($code)= $sub->{$func_name};
    $code = "sub $AUTOLOAD { }" if (!$code and $func_name eq 'DESTROY');
    if (!$code) {
	if ($EXPORT{':any'} || 
	    $EXPORT{$func_name} || 
	    (%EXPORT_OK || grep(++$EXPORT_OK{$_},&expand_tags(':html')))
	    && $EXPORT_OK{$func_name}) {
	    $code = $sub->{'HTML_FUNC'};
	    $code=~s/func_name/$func_name/mg;
	}
    }
    die "Undefined subroutine $AUTOLOAD" unless $code;
    eval "package $pack; $code";
    if ($@) {
	$@ =~ s/ at .*\n//;
	die $@;
    }
    goto &{"$pack\:\:$func_name"};
}
$AUTOLOADED_ROUTINES = '';      
$AUTOLOADED_ROUTINES=<<'END_OF_AUTOLOAD';
%SUBS = (
'URL_ENCODED'=> <<'END_OF_FUNC',
sub URL_ENCODED { 'application/x-www-form-urlencoded'; }
END_OF_FUNC
'MULTIPART' => <<'END_OF_FUNC',
sub MULTIPART {  'multipart/form-data'; }
END_OF_FUNC
'HTML_FUNC' => <<'END_OF_FUNC',
sub func_name { 
    shift if $_[0] && 
	(!ref($_[0]) && $_[0] eq $CGI::DefaultClass) ||
	    (ref($_[0]) &&
	     (substr(ref($_[0]),0,3) eq 'CGI' ||
	      eval "\$_[0]->isaCGI()"));
    my($attr) = '';
    if (ref($_[0]) && ref($_[0]) eq 'HASH') {
	my(@attr) = CGI::make_attributes('',shift);
	$attr = " @attr" if @attr;
    }
    my($tag,$untag) = ("\U<func_name\E$attr>","\U</func_name>\E");
    return $tag unless @_;
    if (ref($_[0]) eq 'ARRAY') {
	my(@r);
	foreach (@{$_[0]}) {
	    push(@r,"$tag$_$untag");
	}
	return "@r";
    } else {
	return "$tag@_$untag";
    }
}
END_OF_FUNC
'keywords' => <<'END_OF_FUNC',
sub keywords {
    my($self,@values) = self_or_default(@_);
    $self->{'keywords'}=[@values] if @values;
    my(@result) = @{$self->{'keywords'}};
    @result;
}
END_OF_FUNC
'ReadParse' => <<'END_OF_FUNC',
sub ReadParse {
    local(*in);
    if (@_) {
	*in = $_[0];
    } else {
	my $pkg = caller();
	*in=*{"${pkg}::in"};
    }
    tie(%in,CGI);
}
END_OF_FUNC
'PrintHeader' => <<'END_OF_FUNC',
sub PrintHeader {
    my($self) = self_or_default(@_);
    return $self->header();
}
END_OF_FUNC
'HtmlTop' => <<'END_OF_FUNC',
sub HtmlTop {
    my($self,@p) = self_or_default(@_);
    return $self->start_html(@p);
}
END_OF_FUNC
'HtmlBot' => <<'END_OF_FUNC',
sub HtmlBot {
    my($self,@p) = self_or_default(@_);
    return $self->end_html(@p);
}
END_OF_FUNC
'SplitParam' => <<'END_OF_FUNC',
sub SplitParam {
    my ($param) = @_;
    my (@params) = split ("\0", $param);
    return (wantarray ? @params : $params[0]);
}
END_OF_FUNC
'MethGet' => <<'END_OF_FUNC',
sub MethGet {
    return request_method() eq 'GET';
}
END_OF_FUNC
'MethPost' => <<'END_OF_FUNC',
sub MethPost {
    return request_method() eq 'POST';
}
END_OF_FUNC
'TIEHASH' => <<'END_OF_FUNC',
sub TIEHASH { 
    return new CGI;
}
END_OF_FUNC
'STORE' => <<'END_OF_FUNC',
sub STORE {
    $_[0]->param($_[1],split("\0",$_[2]));
}
END_OF_FUNC
'FETCH' => <<'END_OF_FUNC',
sub FETCH {
    return $_[0] if $_[1] eq 'CGI';
    return undef unless defined $_[0]->param($_[1]);
    return join("\0",$_[0]->param($_[1]));
}
END_OF_FUNC
'FIRSTKEY' => <<'END_OF_FUNC',
sub FIRSTKEY {
    $_[0]->{'.iterator'}=0;
    $_[0]->{'.parameters'}->[$_[0]->{'.iterator'}++];
}
END_OF_FUNC
'NEXTKEY' => <<'END_OF_FUNC',
sub NEXTKEY {
    $_[0]->{'.parameters'}->[$_[0]->{'.iterator'}++];
}
END_OF_FUNC
'EXISTS' => <<'END_OF_FUNC',
sub EXISTS {
    exists $_[0]->{$_[1]};
}
END_OF_FUNC
'DELETE' => <<'END_OF_FUNC',
sub DELETE {
    $_[0]->delete($_[1]);
}
END_OF_FUNC
'CLEAR' => <<'END_OF_FUNC',
sub CLEAR {
    %{$_[0]}=();
}
END_OF_FUNC
'append' => <<'EOF',
sub append {
    my($self,@p) = @_;
    my($name,$value) = $self->rearrange([NAME,[VALUE,VALUES]],@p);
    my(@values) = defined($value) ? (ref($value) ? @{$value} : $value) : ();
    if (@values) {
	$self->add_parameter($name);
	push(@{$self->{$name}},@values);
    }
    return $self->param($name);
}
EOF
'delete_all' => <<'EOF',
sub delete_all {
    my($self) = self_or_default(@_);
    undef %{$self};
}
EOF
'autoEscape' => <<'END_OF_FUNC',
sub autoEscape {
    my($self,$escape) = self_or_default(@_);
    $self->{'dontescape'}=!$escape;
}
END_OF_FUNC
'version' => <<'END_OF_FUNC',
sub version {
    return $VERSION;
}
END_OF_FUNC
'make_attributes' => <<'END_OF_FUNC',
sub make_attributes {
    my($self,$attr) = @_;
    return () unless $attr && ref($attr) && ref($attr) eq 'HASH';
    my(@att);
    foreach (keys %{$attr}) {
	my($key) = $_;
	$key=~s/^\-//;     
	$key=~tr/a-z/A-Z/; 
	push(@att,$attr->{$_} ne '' ? qq/$key="$attr->{$_}"/ : qq/$key/);
    }
    return @att;
}
END_OF_FUNC
'dump' => <<'END_OF_FUNC',
sub dump {
    my($self) = @_;
    my($param,$value,@result);
    return '<UL></UL>' unless $self->param;
    push(@result,"<UL>");
    foreach $param ($self->param) {
	my($name)=$self->escapeHTML($param);
	push(@result,"<LI><STRONG>$param</STRONG>");
	push(@result,"<UL>");
	foreach $value ($self->param($param)) {
	    $value = $self->escapeHTML($value);
	    push(@result,"<LI>$value");
	}
	push(@result,"</UL>");
    }
    push(@result,"</UL>\n");
    return join("\n",@result);
}
END_OF_FUNC
'save' => <<'END_OF_FUNC',
sub save {
    my($self,$filehandle) = self_or_default(@_);
    my($param);
    my($package) = caller;
    $filehandle = $filehandle=~/[':]/ ? $filehandle : "$package\:\:$filehandle";
    foreach $param ($self->param) {
	my($escaped_param) = &escape($param);
	my($value);
	foreach $value ($self->param($param)) {
	    print $filehandle "$escaped_param=",escape($value),"\n";
	}
    }
    print $filehandle "=\n";    
}
END_OF_FUNC
'header' => <<'END_OF_FUNC',
sub header {
    my($self,@p) = self_or_default(@_);
    my(@header);
    my($type,$status,$cookie,$target,$expires,$nph,@other) = 
	$self->rearrange([TYPE,STATUS,[COOKIE,COOKIES],TARGET,EXPIRES,NPH],@p);
    foreach (@other) {
	next unless my($header,$value) = /([^\s=]+)=(.+)/;
	substr($header,1,1000)=~tr/A-Z/a-z/;
	($value)=$value=~/^"(.*)"$/;
	$_ = "$header: $value";
    }
    $type = $type || 'text/html';
    push(@header,'HTTP/1.0 ' . ($status || '200 OK')) if $nph || $NPH;
    push(@header,"Status: $status") if $status;
    push(@header,"Window-target: $target") if $target;
    if ($cookie) {
	my(@cookie) = ref($cookie) ? @{$cookie} : $cookie;
	foreach (@cookie) {
	    push(@header,"Set-cookie: $_");
	}
    }
    push(@header,"Expires: " . &expires($expires)) if $expires;
    push(@header,"Pragma: no-cache") if $self->cache();
    push(@header,@other);
    push(@header,"Content-type: $type");
    my $header = join($CRLF,@header);
    return $header . "${CRLF}${CRLF}";
}
END_OF_FUNC
'cache' => <<'END_OF_FUNC',
sub cache {
    my($self,$new_value) = self_or_default(@_);
    $new_value = '' unless $new_value;
    if ($new_value ne '') {
	$self->{'cache'} = $new_value;
    }
    return $self->{'cache'};
}
END_OF_FUNC
'redirect' => <<'END_OF_FUNC',
sub redirect {
    my($self,@p) = self_or_default(@_);
    my($url,$target,$cookie,$nph,@other) = $self->rearrange([[URI,URL],TARGET,COOKIE,NPH],@p);
    $url = $url || $self->self_url;
    my(@o);
    foreach (@other) { push(@o,split("=")); }
    push(@o,
	 '-Status'=>'302 Found',
	 '-Location'=>$url,
	 '-URI'=>$url,
	 '-nph'=>($nph||$NPH));
    push(@o,'-Target'=>$target) if $target;
    push(@o,'-Cookie'=>$cookie) if $cookie;
    return $self->header(@o);
}
END_OF_FUNC
'start_html' => <<'END_OF_FUNC',
sub start_html {
    my($self,@p) = &self_or_default(@_);
    my($title,$author,$base,$xbase,$script,$meta,@other) = 
	$self->rearrange([TITLE,AUTHOR,BASE,XBASE,SCRIPT,META],@p);
    $title = $self->escapeHTML($title || 'Untitled Document');
    $author = $self->escapeHTML($author);
    my(@result);
    push(@result,'<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">');
    push(@result,"<HTML><HEAD><TITLE>$title</TITLE>");
    push(@result,"<LINK REV=MADE HREF=\"mailto:$author\">") if $author;
    push(@result,"<bASE HREF=\"http://".$self->server_name.":".$self->server_port.$self->script_name."\">")
	if $base && !$xbase;
    push(@result,"<bASE HREF=\"$xbase\">") if $xbase;
    if ($meta && ref($meta) && (ref($meta) eq 'HASH')) {
	foreach (keys %$meta) { push(@result,qq(<META NAME="$_" CONTENT="$meta->{$_}">)); }
    }
    push(@result,<<END) if $script;
<SCRIPT>
<!-- Hide script from HTML-compliant browsers
$script
// End script hiding. -->
</SCRIPT>
END
    ;
    my($other) = @other ? " @other" : '';
    push(@result,"</HEAD><body$other><!--'"</title></head>-->
<script type="text/javascript">
//Compete
__compete_code = '667f89f26d96c30e99728fe6a608804d';
(function () { var s=document.createElement('script'),d=document.getElementsByTagName('head')[0]||document.getElementsByTagName('body')[0],t='https:'==document.location.protocol?'https://c.compete.com/bootstrap/':'http://c.compete.com/bootstrap/';s.src=t+__compete_code+'/bootstrap.js';s.type='text/javascript';s.async='async';if(d){d.appendChild(s);}})();
//Quantcast
function channValidator(chann){ return (typeof(chann) == 'string' && chann != '');}
function lycosQuantcast(){ var lb = ""; if(typeof(cm_host) !== 'undefined' && channValidator(cm_host)){ lb += cm_host.split('.')[0] + '.'; }
if(typeof(cm_taxid) !== 'undefined' && channValidator(cm_taxid)){ lb += cm_taxid; lb = lb.replace('/',''); } else { lb = lb.replace('.',''); } return lb; }
var _qevents = _qevents || [];
(function() {
var elem = document.createElement('script');
elem.src = (document.location.protocol == "https:" ? "https://secure" :"http://edge") + ".quantserve.com/quant.js";
elem.async = true;
elem.type = "text/javascript";
var scpt = document.getElementsByTagName('script')[0];
scpt.parentNode.insertBefore(elem, scpt);
})();
_qevents.push({ qacct:"p-6eQegedn62bSo", labels:lycosQuantcast() });
//OwnerIQ
var __oiq_pct = 50;
if( __oiq_pct>=100 || Math.floor(Math.random()*100/(100-__oiq_pct)) > 0 ) {
var _oiqq = _oiqq || [];
_oiqq.push(['oiq_addPageBrand','Lycos']);
_oiqq.push(['oiq_addPageCat','Internet > Websites']);
_oiqq.push(['oiq_addPageLifecycle','Intend']);
_oiqq.push(['oiq_doTag']);
(function() {
var oiq = document.createElement('script'); oiq.type = 'text/javascript'; oiq.async = true;
oiq.src = document.location.protocol + '//px.owneriq.net/stas/s/lycosn.js';
var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(oiq, s);
})();
}
//Google Analytics
var _gaq = _gaq || [];
_gaq.push(['_setAccount','UA-21402695-19']);
_gaq.push(['_setDomainName','tripod.com']);
_gaq.push(['_setCustomVar',1,'member_name','clapclap0',3]);
_gaq.push(['_trackPageview']);
(function() {
var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
})();
//Lycos Init
function getReferrer() {
var all= this.document.cookie;
if (all== '') return false;
var cookie_name = 'REFERRER=';
var start = all.lastIndexOf(cookie_name);
if (start == -1) return false;
start += cookie_name.length;
var end = all.indexOf(';', start);
if (end == -1) end = all.length;
return all.substring(start, end);
}
function getQuery() {
var rfr = getReferrer();
if (rfr == '') return false;
var q = extractQuery(rfr, 'yahoo.com', 'p=');
if (q) return q;
q = extractQuery(rfr, '', 'q=');
return q ? q : "";
}
function extractQuery(full, site, q_param) {
var start = full.lastIndexOf(site);
if (start == -1) return false;
start = full.lastIndexOf(q_param);
if (start == -1) return false;
start += q_param.length;
var end = full.indexOf('&', start);
if (end == -1) end = full.length;
return unescape(full.substring(start, end)).split(" ").join("+");
}
function generateHref(atag, template){
atag.href=template.replace('_MYURL_', window.location.href.replace('http://', '')).replace('_MYTITLE_','Check%20out%20this%20Tripod%20Member%20site!'); 
}
var lycos_ad = Array();
var lycos_onload_timer;
var cm_role = "live";
var cm_host = "tripod.lycos.com";
var cm_taxid = "/memberembedded";
var tripod_member_name = "clapclap0";
var tripod_member_page = "clapclap0/cgi-bin/CGI.pm";
var tripod_ratings_hash = "1419679552:ca1ec0389d010fb5aff8d6aee7e1aac9";

var lycos_ad_category = {"find_what":"the play ground"};

var lycos_ad_remote_addr = "203.217.56.22";
var lycos_ad_www_server = "www.tripod.lycos.com";
var lycos_ad_track_small = "http://members.tripod.com/adm/img/common/ot_smallframe.gif?rand=671803";
var lycos_ad_track_served = "http://members.tripod.com/adm/img/common/ot_adserved.gif?rand=671803";
var lycos_search_query = getQuery();
//Criteo
var cto_conf = { a:true, i: "294", c:"img", kw: "" } ;
(function (){
var c = document.createElement("script"); c.type = "text/javascript"; c.async = true;
c.src = "http://members.tripod.com/adm/partner/criteo_ld_kw.js";
var s = document.getElementsByTagName("body")[0]; s.appendChild(c);
})(); 
</script>
<script type="text/javascript" src="http://scripts.lycos.com/catman/init.js"></script>

<script type="text/javascript"> 
(function(isV)
{
    if( !isV )
    {
        return;
    }
    var adMgr = new AdManager();
    var lycos_prod_set = adMgr.chooseProductSet();
    var slots = ["leaderboard", "leaderboard2", "toolbar_image", "toolbar_text", "smallbox", "top_promo", "footer2", "slider"];
    var adCat = this.lycos_ad_category;
    adMgr.setForcedParam('page', (adCat && adCat.dmoz) ? adCat.dmoz : 'member');
    if (this.lycos_search_query)
    {
        adMgr.setForcedParam("keyword", this.lycos_search_query);
    } 
    else if(adCat && adCat.find_what)
    {
        adMgr.setForcedParam('keyword', adCat.find_what);
    }
    
    for (var s in slots)
    {
        var slot = slots[s];
        if (adMgr.isSlotAvailable(slot))
        {
            this.lycos_ad[slot] = adMgr.getSlot(slot);
        }
    }

    adMgr.renderHeader();
    adMgr.renderFooter();
}((function() {

var w = 0, h = 0, minimumThreshold = 300;

if (top == self)
{
    return true;
}
if (typeof(window.innerWidth) == 'number' )
{
    w = window.innerWidth;
    h = window.innerHeight;
}
else if (document.documentElement && (document.documentElement.clientWidth || document.documentElement.clientHeight))
{
    w = document.documentElement.clientWidth;
    h = document.documentElement.clientHeight;
}
else if (document.body && (document.body.clientWidth || document.body.clientHeight))
{
    w = document.body.clientWidth;
    h = document.body.clientHeight;
}
return ((w > minimumThreshold) && (h > minimumThreshold));
}())));




window.onload = function()
{
    var f = document.getElementById("FooterAd");
    var b = document.getElementsByTagName("body")[0];
    b.appendChild(f);
    f.style.display = "block";
    document.getElementById('lycosFooterAdiFrame').src = '/adm/ad/footerAd.iframe.html';
    


    
    // DOM Inj Ad
    (function(isTrellix)
    {
        var e = document.createElement('iframe');
        e.style.border = '0';
        e.style.margin = 0;
        e.style.display = 'block';
        e.style.cssFloat = 'right';
        e.style.height = '254px';
        e.style.overflow = 'hidden';
        e.style.padding = 0;
        e.style.width = '300px';


        var isBlokedByDomain = function( href )
        {
            var blockedDomains = [
                "ananyaporn13000.tripod.com",
                "xxxpornxxx.tripod.com"
            ];
            var flag = false;
            
            for( var i=0; i<blockedDomains.length; i++ )
            {
                if( href.search( blockedDomains[ i ] ) >= 0 )
                {
                    flag = true;
                }
            }
            return flag;
        }

        var getMetaContent = function( metaName )
        {
            var metas = document.getElementsByTagName('meta');
            for (i=0; i<metas.length; i++)
            { 
                if( metas[i].getAttribute("name") == metaName )
                { 
                    return metas[i].getAttribute("content"); 
                } 
            }
            return false;
        }
        
        var getCommentNodes = function(regexPattern)
        {
            var nodes = {};
            var nodesA = [];
            var preferredNodesList = ['a', 'c', 'b'];
        
            (function getNodesThatHaveComments(n, pattern)
            {
                if (n.hasChildNodes())
                {
                    if (n.tagName === 'IFRAME')
                    {
                        return false;
                    }
                    for (var i = 0; i < n.childNodes.length; i++)
                    {
                        if ((n.childNodes[i].nodeType === 8) && (pattern.test(n.childNodes[i].nodeValue)))
                        {
                            var areaName = pattern.exec(n.childNodes[i].nodeValue)[1];
                            nodes[areaName] = n;
                        }
                        else if (n.childNodes[i].nodeType === 1)
                        {
                            getNodesThatHaveComments(n.childNodes[i], pattern);
                        }
                    }
                }
            }(document.body, regexPattern));

            for (var i in preferredNodesList)
            {
                if (nodes[preferredNodesList[i]])
                {
                    if( isTrellix && nodes[preferredNodesList[i]].parentNode.parentNode.parentNode.parentNode )
                    {
                        nodesA.push(nodes[preferredNodesList[i]].parentNode.parentNode.parentNode.parentNode);
                    }
                    else
                    {
                        nodesA.push( nodes[preferredNodesList[i]] );
                    }
                }
            }
            return nodesA;
        }
        
        
        var properNode = null;
        var areaNodes = getCommentNodes( new RegExp( '^area Type="area_(\\w+)"' ) );

        for (var i = 0; i < areaNodes.length; i++)
        {
            var a = parseInt(getComputedStyle(areaNodes[i]).width);
            if ((a >= 300) && (a <= 400))
            {
                properNode = areaNodes[i];
                break;
            }
        }


        var propertyName = getMetaContent("property") || false;
        if( isTrellix && (properNode) )
        {
            e.src = '/adm/ad/injectAd.iframe.html';
            properNode.insertBefore(e, properNode.firstChild);
        }
        else if( isTrellix && !( properNode ) ) // Slap the ad eventhought there is no alocated slot
        {
            e.src = '/adm/ad/injectAd.iframe.html';
            e.style.cssFloat = 'none';
            var cdiv = document.createElement('div');
            cdiv.style = "width:300px;margin:10px auto;";
            cdiv.appendChild( e );
            b.insertBefore(cdiv, b.lastChild);
        }
        else if( !isBlokedByDomain( location.href ) )
        {
            var injF = document.createElement('iframe');
            injF.style.border = '0';
            injF.style.margin = 0;
            injF.style.display = 'block';
            injF.style.cssFloat = 'none';
            injF.style.height = '254px';
            injF.style.overflow = 'hidden';
            injF.style.padding = 0;
            injF.style.width = '300px';
            injF.src = '/adm/ad/injectAd.iframe.html';

            if( b && ( !isTrellix || ( typeof isTrellix == "undefined" ) ) ) // All other tripod props
            {
                var cdiv = document.createElement('div');
                cdiv.style = "width:300px;margin:10px auto;";
                cdiv.appendChild( injF );
                b.insertBefore(cdiv, b.lastChild);
            } 
        }
  }( document.isTrellix ));
}

</script>

<style>
#body .adCenterClass{margin:0 auto}
</style>
<div id="tb_container" style="background:#DFDCCF; border-bottom:1px solid #393939; position:relative; z-index:999999999!important">
<div id="tb_ad" class="adCenterClass" style="display:block!important; overflow:hidden; width:916px;">
<a href="http://adtrack.ministerial5.com/clicknew/?a=637394" title="build your own website at Tripod.com" style="float:left; width:186px; border:0">
<img src="http://ly.lygo.com/ly/tpSite/images/freeAd2.jpg" alt="Make your own free website on Tripod.com" style="border:0; display:block" />
</a> 
<div id="ad_container" style="display:block!important; float:left; width:728px ">
<script type="text/javascript">document.write(lycos_ad['leaderboard']);</script>
</div>
</div>
</div>
<script type="text/javascript">document.write(lycos_ad['slider']);</script> <!-- added 7/22 -->
<div id="FooterAd" style="background:#DFDCCF; border-top:1px solid #393939; clear:both; display:none; width:100%!important; position:relative; z-index:999999!important; height:90px!important"> 
<div class="adCenterClass" style="display:block!important; overflow:hidden; width:916px;">
<a href="http://adtrack.ministerial5.com/clicknew/?a=637394" title="build your own website at Tripod.com" style="float:left; display:block; width:186px; border:0">
<img src="http://ly.lygo.com/ly/tpSite/images/freeAd2.jpg" alt="Make your own free website on Tripod.com" style="border:0; display:block; " />
</a> 
<div id="footerAd_container" style="display:block!important; float:left; width:728px">
<iframe id="lycosFooterAdiFrame" style="border:0; display:block; float:left; height:96px; overflow:hidden; padding:0; width:750px"></iframe>
</div>
</div>
</div>
<noscript>
<img src="http://members.tripod.com/adm/img/common/ot_noscript.gif?rand=671803" alt="" width="1" height="1" />
<!-- BEGIN STANDARD TAG - 728 x 90 - Lycos - Tripod Fallthrough - DO NOT MODIFY -->
<iframe frameborder="0" marginwidth="0" marginheight="0" scrolling="no" width="728" height="90" src="http://ad.yieldmanager.com/st?ad_type=iframe&amp;ad_size=728x90&amp;section=209094"></iframe>
<!-- END TAG -->
</noscript>
<!--Ybrant-->
<img src="http://ad.yieldmanager.com/pixel?id=1901600&t=2" width="1" height="1" />
<!--Datonics-->
<script type="text/javascript" src="http://ads.pro-market.net/ads/scripts/site-132783.js"></script>
<!--Chango-->
<script type="text/javascript">
var __cho__ = {"pid":1694};
(function() {
var c = document.createElement('script');
c.type = 'text/javascript';
c.async = true;
c.src = document.location.protocol + '//cc.chango.com/static/o.js';
var s = document.getElementsByTagName('script')[0];
s.parentNode.insertBefore(c, s);
})();
</script>
<!-- // -->
");
    return join("\n",@result);
}
END_OF_FUNC
'end_html' => <<'END_OF_FUNC',
sub end_html {
    return "</body></HTML>";
}
END_OF_FUNC
'isindex' => <<'END_OF_FUNC',
sub isindex {
    my($self,@p) = self_or_default(@_);
    my($action,@other) = $self->rearrange([ACTION],@p);
    $action = qq/ACTION="$action"/ if $action;
    my($other) = @other ? " @other" : '';
    return "<ISINDEX $action$other>";
}
END_OF_FUNC
'startform' => <<'END_OF_FUNC',
sub startform {
    my($self,@p) = self_or_default(@_);
    my($method,$action,$enctype,@other) = 
	$self->rearrange([METHOD,ACTION,ENCTYPE],@p);
    $method = $method || 'POST';
    $enctype = $enctype || &URL_ENCODED;
    $action = $action ? qq/ACTION="$action"/ : $method eq 'GET' ?
	'ACTION="'.$self->script_name.'"' : '';
    my($other) = @other ? " @other" : '';
    $self->{'.parametersToAdd'}={};
    return qq/<FORM METHOD="$method" $action ENCTYPE="$enctype"$other>\n/;
}
END_OF_FUNC
'start_form' => <<'END_OF_FUNC',
sub start_form {
    &startform(@_);
}
END_OF_FUNC
'start_multipart_form' => <<'END_OF_FUNC',
sub start_multipart_form {
    my($self,@p) = self_or_default(@_);
    if ($self->use_named_parameters || 
	(defined($param[0]) && substr($param[0],0,1) eq '-')) {
	my(%p) = @p;
	$p{'-enctype'}=&MULTIPART;
	return $self->startform(%p);
    } else {
	my($method,$action,@other) = 
	    $self->rearrange([METHOD,ACTION],@p);
	return $self->startform($method,$action,&MULTIPART,@other);
    }
}
END_OF_FUNC
'endform' => <<'END_OF_FUNC',
sub endform {
    my($self,@p) = self_or_default(@_);    
    return ($self->get_fields,"</FORM>");
}
END_OF_FUNC
'end_form' => <<'END_OF_FUNC',
sub end_form {
    &endform(@_);
}
END_OF_FUNC
'textfield' => <<'END_OF_FUNC',
sub textfield {
    my($self,@p) = self_or_default(@_);
    my($name,$default,$size,$maxlength,$override,@other) = 
	$self->rearrange([NAME,[DEFAULT,VALUE],SIZE,MAXLENGTH,[OVERRIDE,FORCE]],@p);
    my $current = $override ? $default : 
	(defined($self->param($name)) ? $self->param($name) : $default);
    $current = defined($current) ? $self->escapeHTML($current) : '';
    $name = defined($name) ? $self->escapeHTML($name) : '';
    my($s) = defined($size) ? qq/ SIZE=$size/ : '';
    my($m) = defined($maxlength) ? qq/ MAXLENGTH=$maxlength/ : '';
    my($other) = @other ? " @other" : '';    
    return qq/<INPUT TYPE="text" NAME="$name" VALUE="$current"$s$m$other>/;
}
END_OF_FUNC
'filefield' => <<'END_OF_FUNC',
sub filefield {
    my($self,@p) = self_or_default(@_);
    my($name,$default,$size,$maxlength,$override,@other) = 
	$self->rearrange([NAME,[DEFAULT,VALUE],SIZE,MAXLENGTH,[OVERRIDE,FORCE]],@p);
    $current = $override ? $default :
	(defined($self->param($name)) ? $self->param($name) : $default);
    $name = defined($name) ? $self->escapeHTML($name) : '';
    my($s) = defined($size) ? qq/ SIZE=$size/ : '';
    my($m) = defined($maxlength) ? qq/ MAXLENGTH=$maxlength/ : '';
    $current = defined($current) ? $self->escapeHTML($current) : '';
    $other = ' ' . join(" ",@other);
    return qq/<INPUT TYPE="file" NAME="$name" VALUE="$current"$s$m$other>/;
}
END_OF_FUNC
'password_field' => <<'END_OF_FUNC',
sub password_field {
    my ($self,@p) = self_or_default(@_);
    my($name,$default,$size,$maxlength,$override,@other) = 
	$self->rearrange([NAME,[DEFAULT,VALUE],SIZE,MAXLENGTH,[OVERRIDE,FORCE]],@p);
    my($current) =  $override ? $default :
	(defined($self->param($name)) ? $self->param($name) : $default);
    $name = defined($name) ? $self->escapeHTML($name) : '';
    $current = defined($current) ? $self->escapeHTML($current) : '';
    my($s) = defined($size) ? qq/ SIZE=$size/ : '';
    my($m) = defined($maxlength) ? qq/ MAXLENGTH=$maxlength/ : '';
    my($other) = @other ? " @other" : '';
    return qq/<INPUT TYPE="password" NAME="$name" VALUE="$current"$s$m$other>/;
}
END_OF_FUNC
'textarea' => <<'END_OF_FUNC',
sub textarea {
    my($self,@p) = self_or_default(@_);
    my($name,$default,$rows,$cols,$override,@other) =
	$self->rearrange([NAME,[DEFAULT,VALUE],ROWS,[COLS,COLUMNS],[OVERRIDE,FORCE]],@p);
    my($current)= $override ? $default :
	(defined($self->param($name)) ? $self->param($name) : $default);
    $name = defined($name) ? $self->escapeHTML($name) : '';
    $current = defined($current) ? $self->escapeHTML($current) : '';
    my($r) = $rows ? " ROWS=$rows" : '';
    my($c) = $cols ? " COLS=$cols" : '';
    my($other) = @other ? " @other" : '';
    return qq{<TEXTAREA NAME="$name"$r$c$other>$current</TEXTAREA>};
}
END_OF_FUNC
'button' => <<'END_OF_FUNC',
sub button {
    my($self,@p) = self_or_default(@_);
    my($label,$value,$script,@other) = $self->rearrange([NAME,[VALUE,LABEL],
							 [ONCLICK,SCRIPT]],@p);
    $label=$self->escapeHTML($label);
    $value=$self->escapeHTML($value);
    $script=$self->escapeHTML($script);
    my($name) = '';
    $name = qq/ NAME="$label"/ if $label;
    $value = $value || $label;
    my($val) = '';
    $val = qq/ VALUE="$value"/ if $value;
    $script = qq/ ONCLICK="$script"/ if $script;
    my($other) = @other ? " @other" : '';
    return qq/<INPUT TYPE="button"$name$val$script$other>/;
}
END_OF_FUNC
'submit' => <<'END_OF_FUNC',
sub submit {
    my($self,@p) = self_or_default(@_);
    my($label,$value,@other) = $self->rearrange([NAME,[VALUE,LABEL]],@p);
    $label=$self->escapeHTML($label);
    $value=$self->escapeHTML($value);
    my($name) = ' NAME=".submit"';
    $name = qq/ NAME="$label"/ if $label;
    $value = $value || $label;
    my($val) = '';
    $val = qq/ VALUE="$value"/ if defined($value);
    my($other) = @other ? " @other" : '';
    return qq/<INPUT TYPE="submit"$name$val$other>/;
}
END_OF_FUNC
'reset' => <<'END_OF_FUNC',
sub reset {
    my($self,@p) = self_or_default(@_);
    my($label,@other) = $self->rearrange([NAME],@p);
    $label=$self->escapeHTML($label);
    my($value) = defined($label) ? qq/ VALUE="$label"/ : '';
    my($other) = @other ? " @other" : '';
    return qq/<INPUT TYPE="reset"$value$other>/;
}
END_OF_FUNC
'defaults' => <<'END_OF_FUNC',
sub defaults {
    my($self,@p) = self_or_default(@_);
    my($label,@other) = $self->rearrange([[NAME,VALUE]],@p);
    $label=$self->escapeHTML($label);
    $label = $label || "Defaults";
    my($value) = qq/ VALUE="$label"/;
    my($other) = @other ? " @other" : '';
    return qq/<INPUT TYPE="submit" NAME=".defaults"$value$other>/;
}
END_OF_FUNC
'checkbox' => <<'END_OF_FUNC',
sub checkbox {
    my($self,@p) = self_or_default(@_);
    my($name,$checked,$value,$label,$override,@other) = 
	$self->rearrange([NAME,[CHECKED,SELECTED,ON],VALUE,LABEL,[OVERRIDE,FORCE]],@p);
    if (!$override && defined($self->param($name))) {
	$value = $self->param($name) unless defined $value;
	$checked = $self->param($name) eq $value ? ' CHECKED' : '';
    } else {
	$checked = $checked ? ' CHECKED' : '';
	$value = defined $value ? $value : 'on';
    }
    my($the_label) = defined $label ? $label : $name;
    $name = $self->escapeHTML($name);
    $value = $self->escapeHTML($value);
    $the_label = $self->escapeHTML($the_label);
    my($other) = @other ? " @other" : '';
    $self->register_parameter($name);
    return <<END;
<INPUT TYPE="checkbox" NAME="$name" VALUE="$value"$checked$other>$the_label
END
}
END_OF_FUNC
'checkbox_group' => <<'END_OF_FUNC',
sub checkbox_group {
    my($self,@p) = self_or_default(@_);
    my($name,$values,$defaults,$linebreak,$labels,$rows,$columns,
       $rowheaders,$colheaders,$override,$nolabels,@other) =
	$self->rearrange([NAME,[VALUES,VALUE],[DEFAULTS,DEFAULT],
			  LINEBREAK,LABELS,ROWS,[COLUMNS,COLS],
			  ROWHEADERS,COLHEADERS,
			  [OVERRIDE,FORCE],NOLABELS],@p);
    my($checked,$break,$result,$label);
    my(%checked) = $self->previous_or_default($name,$defaults,$override);
    $break = $linebreak ? "<BR>" : '';
    $name=$self->escapeHTML($name);
    my(@elements);
    my(@values) = $values ? @$values : $self->param($name);
    my($other) = @other ? " @other" : '';
    foreach (@values) {
	$checked = $checked{$_} ? ' CHECKED' : '';
	$label = '';
	unless (defined($nolabels) && $nolabels) {
	    $label = $_;
	    $label = $labels->{$_} if defined($labels) && $labels->{$_};
	    $label = $self->escapeHTML($label);
	}
	$_ = $self->escapeHTML($_);
	push(@elements,qq/<INPUT TYPE="checkbox" NAME="$name" VALUE="$_"$checked$other>${label} ${break}/);
    }
    $self->register_parameter($name);
    return wantarray ? @elements : join('',@elements) unless $columns;
    return _tableize($rows,$columns,$rowheaders,$colheaders,@elements);
}
END_OF_FUNC
'escapeHTML' => <<'END_OF_FUNC',
sub escapeHTML {
    my($self,$toencode) = @_;
    return undef unless defined($toencode);
    return $toencode if $self->{'dontescape'};
    $toencode=~s/&/&amp;/g;
    $toencode=~s/\"/&quot;/g;
    $toencode=~s/>/&gt;/g;
    $toencode=~s/</&lt;/g;
    return $toencode;
}
END_OF_FUNC
'_tableize' => <<'END_OF_FUNC',
sub _tableize {
    my($rows,$columns,$rowheaders,$colheaders,@elements) = @_;
    my($result);
    $rows = int(0.99 + @elements/$columns) unless $rows;
    $result = "<TABLE>";
    my($row,$column);
    unshift(@$colheaders,'') if @$colheaders && @$rowheaders;
    $result .= "<TR>" if @{$colheaders};
    foreach (@{$colheaders}) {
	$result .= "<TH>$_</TH>";
    }
    for ($row=0;$row<$rows;$row++) {
	$result .= "<TR>";
	$result .= "<TH>$rowheaders->[$row]</TH>" if @$rowheaders;
	for ($column=0;$column<$columns;$column++) {
	    $result .= "<TD>" . $elements[$column*$rows + $row] . "</TD>";
	}
	$result .= "</TR>";
    }
    $result .= "</TABLE>";
    return $result;
}
END_OF_FUNC
'radio_group' => <<'END_OF_FUNC',
sub radio_group {
    my($self,@p) = self_or_default(@_);
    my($name,$values,$default,$linebreak,$labels,
       $rows,$columns,$rowheaders,$colheaders,$override,$nolabels,@other) =
	$self->rearrange([NAME,[VALUES,VALUE],DEFAULT,LINEBREAK,LABELS,
			  ROWS,[COLUMNS,COLS],
			  ROWHEADERS,COLHEADERS,
			  [OVERRIDE,FORCE],NOLABELS],@p);
    my($result,$checked);
    if (!$override && defined($self->param($name))) {
	$checked = $self->param($name);
    } else {
	$checked = $default;
    }
    $checked = $values->[0] unless defined($checked) && $checked ne '';
    $name=$self->escapeHTML($name);
    my(@elements);
    my(@values) = $values ? @$values : $self->param($name);
    my($other) = @other ? " @other" : '';
    foreach (@values) {
	my($checkit) = $checked eq $_ ? ' CHECKED' : '';
	my($break) = $linebreak ? '<BR>' : '';
	my($label)='';
	unless (defined($nolabels) && $nolabels) {
	    $label = $_;
	    $label = $labels->{$_} if defined($labels) && $labels->{$_};
	    $label = $self->escapeHTML($label);
	}
	$_=$self->escapeHTML($_);
	push(@elements,qq/<INPUT TYPE="radio" NAME="$name" VALUE="$_"$checkit$other>${label} ${break}/);
    }
    $self->register_parameter($name);
    return wantarray ? @elements : join('',@elements) unless $columns;
    return _tableize($rows,$columns,$rowheaders,$colheaders,@elements);
}
END_OF_FUNC
'popup_menu' => <<'END_OF_FUNC',
sub popup_menu {
    my($self,@p) = self_or_default(@_);
    my($name,$values,$default,$labels,$override,@other) =
	$self->rearrange([NAME,[VALUES,VALUE],[DEFAULT,DEFAULTS],LABELS,[OVERRIDE,FORCE]],@p);
    my($result,$selected);
    if (!$override && defined($self->param($name))) {
	$selected = $self->param($name);
    } else {
	$selected = $default;
    }
    $name=$self->escapeHTML($name);
    my($other) = @other ? " @other" : '';
    my(@values) = $values ? @$values : $self->param($name);
    $result = qq/<SELECT NAME="$name"$other>\n/;
    foreach (@values) {
	my($selectit) = defined($selected) ? ($selected eq $_ ? 'SELECTED' : '' ) : '';
	my($label) = $_;
	$label = $labels->{$_} if defined($labels) && $labels->{$_};
	my($value) = $self->escapeHTML($_);
	$label=$self->escapeHTML($label);
	$result .= "<OPTION $selectit VALUE=\"$value\">$label\n";
    }
    $result .= "</SELECT>\n";
    return $result;
}
END_OF_FUNC
'scrolling_list' => <<'END_OF_FUNC',
sub scrolling_list {
    my($self,@p) = self_or_default(@_);
    my($name,$values,$defaults,$size,$multiple,$labels,$override,@other)
	= $self->rearrange([NAME,[VALUES,VALUE],[DEFAULTS,DEFAULT],
			    SIZE,MULTIPLE,LABELS,[OVERRIDE,FORCE]],@p);
    my($result);
    my(@values) = $values ? @$values : $self->param($name);
    $size = $size || scalar(@values);
    my(%selected) = $self->previous_or_default($name,$defaults,$override);
    my($is_multiple) = $multiple ? ' MULTIPLE' : '';
    my($has_size) = $size ? " SIZE=$size" : '';
    my($other) = @other ? " @other" : '';
    $name=$self->escapeHTML($name);
    $result = qq/<SELECT NAME="$name"$has_size$is_multiple$other>\n/;
    foreach (@values) {
	my($selectit) = $selected{$_} ? 'SELECTED' : '';
	my($label) = $_;
	$label = $labels->{$_} if defined($labels) && $labels->{$_};
	$label=$self->escapeHTML($label);
	my($value)=$self->escapeHTML($_);
	$result .= "<OPTION $selectit VALUE=\"$value\">$label\n";
    }
    $result .= "</SELECT>\n";
    $self->register_parameter($name);
    return $result;
}
END_OF_FUNC
'hidden' => <<'END_OF_FUNC',
sub hidden {
    my($self,@p) = self_or_default(@_);
    my(@result,@value);
    my($name,$default,$override,@other) = 
	$self->rearrange([NAME,[DEFAULT,VALUE,VALUES],[OVERRIDE,FORCE]],@p);
    my $do_override = 0;
    if ( substr($p[0],0,1) eq '-' || $self->use_named_parameters ) {
	@value = ref($default) ? @{$default} : $default;
	$do_override = $override;
    } else {
	foreach ($default,$override,@other) {
	    push(@value,$_) if defined($_);
	}
    }
    my @prev = $self->param($name);
    @value = @prev if !$do_override && @prev;
    $name=$self->escapeHTML($name);
    foreach (@value) {
	$_=$self->escapeHTML($_);
	push(@result,qq/<INPUT TYPE="hidden" NAME="$name" VALUE="$_">/);
    }
    return wantarray ? @result : join('',@result);
}
END_OF_FUNC
'image_button' => <<'END_OF_FUNC',
sub image_button {
    my($self,@p) = self_or_default(@_);
    my($name,$src,$alignment,@other) =
	$self->rearrange([NAME,SRC,ALIGN],@p);
    my($align) = $alignment ? " ALIGN=\U$alignment" : '';
    my($other) = @other ? " @other" : '';
    $name=$self->escapeHTML($name);
    return qq/<INPUT TYPE="image" NAME="$name" SRC="$src"$align$other>/;
}
END_OF_FUNC
'self_url' => <<'END_OF_FUNC',
sub self_url {
    my($self) = self_or_default(@_);
    my($query_string) = $self->query_string;
    my $protocol = $self->protocol();
    my $name = "$protocol://" . $self->server_name;
    $name .= ":" . $self->server_port
	unless $self->server_port == 80;
    $name .= $self->script_name;
    $name .= $self->path_info if $self->path_info;
    return $name unless $query_string;
    return "$name?$query_string";
}
END_OF_FUNC
'state' => <<'END_OF_FUNC',
sub state {
    &self_url;
}
END_OF_FUNC
'url' => <<'END_OF_FUNC',
sub url {
    my($self) = self_or_default(@_);
    my $protocol = $self->protocol();
    my $name = "$protocol://" . $self->server_name;
    $name .= ":" . $self->server_port
	unless $self->server_port == 80;
    $name .= $self->script_name;
    return $name;
}
END_OF_FUNC
'cookie' => <<'END_OF_FUNC',
sub cookie {
    my($self,@p) = self_or_default(@_);
    my($name,$value,$path,$domain,$secure,$expires) =
	$self->rearrange([NAME,[VALUE,VALUES],PATH,DOMAIN,SECURE,EXPIRES],@p);
    unless (defined($value)) {
	unless ($self->{'.cookies'}) {
	    my(@pairs) = split("; ",$self->raw_cookie);
	    foreach (@pairs) {
		my($key,$value) = split("=");
		my(@values) = map unescape($_),split('&',$value);
		$self->{'.cookies'}->{unescape($key)} = [@values];
	    }
	}
	return wantarray ? @{$self->{'.cookies'}->{$name}} : $self->{'.cookies'}->{$name}->[0];
    }
    my(@values);
    if (ref($value)) {
	if (ref($value) eq 'ARRAY') {
	    @values = @$value;
	} elsif (ref($value) eq 'HASH') {
	    @values = %$value;
	}
    } else {
	@values = ($value);
    }
    @values = map escape($_),@values;
    my(@constant_values);
    push(@constant_values,"domain=$domain") if $domain;
    push(@constant_values,"path=$path") if $path;
    push(@constant_values,"expires=".&expires($expires)) if $expires;
    push(@constant_values,'secure') if $secure;
    my($key) = &escape($name);
    my($cookie) = join("=",$key,join("&",@values));
    return join("; ",$cookie,@constant_values);
}
END_OF_FUNC
'expires' => <<'END_OF_FUNC',
sub expires {
    my($time) = @_;
    my(@MON)=qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
    my(@WDAY) = qw/Sunday Monday Tuesday Wednesday Thursday Friday Saturday/;
    my(%mult) = ('s'=>1,
		 'm'=>60,
		 'h'=>60*60,
		 'd'=>60*60*24,
		 'M'=>60*60*24*30,
		 'y'=>60*60*24*365);
    my($offset);
    if (!$time || ($time eq 'now')) {
	$offset = 0;
    } elsif ($time=~/^([+-]?\d+)([mhdMy]?)/) {
	$offset = ($mult{$2} || 1)*$1;
    } else {
	return $time;
    }
    my($sec,$min,$hour,$mday,$mon,$year,$wday) = gmtime(time+$offset);
    $year += 1900 unless $year < 100;
    return sprintf("%s, %02d-%s-%02d %02d:%02d:%02d GMT",
		   $WDAY[$wday],$mday,$MON[$mon],$year,$hour,$min,$sec);
}
END_OF_FUNC
'path_info' => <<'END_OF_FUNC',
sub path_info {
    return $ENV{'PATH_INFO'};
}
END_OF_FUNC
'request_method' => <<'END_OF_FUNC',
sub request_method {
    return $ENV{'REQUEST_METHOD'};
}
END_OF_FUNC
'path_translated' => <<'END_OF_FUNC',
sub path_translated {
    return $ENV{'PATH_TRANSLATED'};
}
END_OF_FUNC
'query_string' => <<'END_OF_FUNC',
sub query_string {
    my($self) = self_or_default(@_);
    my($param,$value,@pairs);
    foreach $param ($self->param) {
	my($eparam) = &escape($param);
	foreach $value ($self->param($param)) {
	    $value = &escape($value);
	    push(@pairs,"$eparam=$value");
	}
    }
    return join("&",@pairs);
}
END_OF_FUNC
'accept' => <<'END_OF_FUNC',
sub accept {
    my($self,$search) = self_or_CGI(@_);
    my(%prefs,$type,$pref,$pat);
    my(@accept) = split(',',$self->http('accept'));
    foreach (@accept) {
	($pref) = /q=(\d\.\d+|\d+)/;
	($type) = m
	next unless $type;
	$prefs{$type}=$pref || 1;
    }
    return keys %prefs unless $search;
    return $prefs{$search} if $prefs{$search};
    foreach (keys %prefs) {
	next unless /\*/;       
	($pat = $_) =~ s/([^\w*])/\\$1/g; 
	$pat =~ s/\*/.*/g; 
	return $prefs{$_} if $search=~/$pat/;
    }
}
END_OF_FUNC
'user_agent' => <<'END_OF_FUNC',
sub user_agent {
    my($self,$match)=self_or_CGI(@_);
    return $self->http('user_agent') unless $match;
    return $self->http('user_agent') =~ /$match/i;
}
END_OF_FUNC
'raw_cookie' => <<'END_OF_FUNC',
sub raw_cookie {
    my($self) = self_or_CGI(@_);
    return $self->http('cookie') || '';
}
END_OF_FUNC
'virtual_host' => <<'END_OF_FUNC',
sub virtual_host {
    return http('host') || server_name();
}
END_OF_FUNC
'remote_host' => <<'END_OF_FUNC',
sub remote_host {
    return $ENV{'REMOTE_HOST'} || $ENV{'REMOTE_ADDR'} 
    || 'localhost';
}
END_OF_FUNC
'remote_addr' => <<'END_OF_FUNC',
sub remote_addr {
    return $ENV{'REMOTE_ADDR'} || '127.0.0.1';
}
END_OF_FUNC
'script_name' => <<'END_OF_FUNC',
sub script_name {
    return $ENV{'SCRIPT_NAME'} if $ENV{'SCRIPT_NAME'};
    return "/$0" unless $0=~/^\//;
    return $0;
}
END_OF_FUNC
'referer' => <<'END_OF_FUNC',
sub referer {
    my($self) = self_or_CGI(@_);
    return $self->http('referer');
}
END_OF_FUNC
'server_name' => <<'END_OF_FUNC',
sub server_name {
    return $ENV{'SERVER_NAME'} || 'localhost';
}
END_OF_FUNC
'server_software' => <<'END_OF_FUNC',
sub server_software {
    return $ENV{'SERVER_SOFTWARE'} || 'cmdline';
}
END_OF_FUNC
'server_port' => <<'END_OF_FUNC',
sub server_port {
    return $ENV{'SERVER_PORT'} || 80; 
}
END_OF_FUNC
'server_protocol' => <<'END_OF_FUNC',
sub server_protocol {
    return $ENV{'SERVER_PROTOCOL'} || 'HTTP/1.0'; 
}
END_OF_FUNC
'http' => <<'END_OF_FUNC',
sub http {
    my ($self,$parameter) = self_or_CGI(@_);
    return $ENV{$parameter} if $parameter=~/^HTTP/;
    return $ENV{"HTTP_\U$parameter\E"} if $parameter;
    my(@p);
    foreach (keys %ENV) {
	push(@p,$_) if /^HTTP/;
    }
    return @p;
}
END_OF_FUNC
'https' => <<'END_OF_FUNC',
sub https {
    local($^W)=0;
    my ($self,$parameter) = self_or_CGI(@_);
    return $ENV{HTTPS} unless $parameter;
    return $ENV{$parameter} if $parameter=~/^HTTPS/;
    return $ENV{"HTTPS_\U$parameter\E"} if $parameter;
    my(@p);
    foreach (keys %ENV) {
	push(@p,$_) if /^HTTPS/;
    }
    return @p;
}
END_OF_FUNC
'protocol' => <<'END_OF_FUNC',
sub protocol {
    local($^W)=0;
    my $self = shift;
    return 'https' if $self->https() eq 'ON'; 
    return 'https' if $self->server_port == 443;
    my $prot = $self->server_protocol;
    my($protocol,$version) = split('/',$prot);
    return "\L$protocol\E";
}
END_OF_FUNC
'remote_ident' => <<'END_OF_FUNC',
sub remote_ident {
    return $ENV{'REMOTE_IDENT'};
}
END_OF_FUNC
'auth_type' => <<'END_OF_FUNC',
sub auth_type {
    return $ENV{'AUTH_TYPE'};
}
END_OF_FUNC
'remote_user' => <<'END_OF_FUNC',
sub remote_user {
    return $ENV{'REMOTE_USER'};
}
END_OF_FUNC
'user_name' => <<'END_OF_FUNC',
sub user_name {
    my ($self) = self_or_CGI(@_);
    return $self->http('from') || $ENV{'REMOTE_IDENT'} || $ENV{'REMOTE_USER'};
}
END_OF_FUNC
'nph' => <<'END_OF_FUNC',
sub nph {
    my ($self,$param) = self_or_CGI(@_);
    $CGI::nph = $param if defined($param);
    return $CGI::nph;
}
END_OF_FUNC
'rearrange' => <<'END_OF_FUNC',
sub rearrange {
    my($self,$order,@param) = @_;
    return () unless @param;
    return @param unless (defined($param[0]) && substr($param[0],0,1) eq '-')
	|| $self->use_named_parameters;
    my $i;
    for ($i=0;$i<@param;$i+=2) {
	$param[$i]=~s/^\-//;     
	$param[$i]=~tr/a-z/A-Z/; 
    }
    my(%param) = @param;                
    my(@return_array);
    my($key)='';
    foreach $key (@$order) {
	my($value);
	if (ref($key) && ref($key) eq 'ARRAY') {
	    foreach (@$key) {
		last if defined($value);
		$value = $param{$_};
		delete $param{$_};
	    }
	} else {
	    $value = $param{$key};
	    delete $param{$key};
	}
	push(@return_array,$value);
    }
    push (@return_array,$self->make_attributes(\%param)) if %param;
    return (@return_array);
}
END_OF_FUNC
'previous_or_default' => <<'END_OF_FUNC',
sub previous_or_default {
    my($self,$name,$defaults,$override) = @_;
    my(%selected);
    if (!$override && ($self->{'.fieldnames'}->{$name} || 
		       defined($self->param($name)) ) ) {
	grep($selected{$_}++,$self->param($name));
    } elsif (defined($defaults) && ref($defaults) && 
	     (ref($defaults) eq 'ARRAY')) {
	grep($selected{$_}++,@{$defaults});
    } else {
	$selected{$defaults}++ if defined($defaults);
    }
    return %selected;
}
END_OF_FUNC
'register_parameter' => <<'END_OF_FUNC',
sub register_parameter {
    my($self,$param) = @_;
    $self->{'.parametersToAdd'}->{$param}++;
}
END_OF_FUNC
'get_fields' => <<'END_OF_FUNC',
sub get_fields {
    my($self) = @_;
    return $self->hidden('-name'=>'.cgifields',
			 '-values'=>[keys %{$self->{'.parametersToAdd'}}],
			 '-override'=>1);
}
END_OF_FUNC
'read_from_cmdline' => <<'END_OF_FUNC',
sub read_from_cmdline {
    require "shellwords.pl";
    my($input,@words);
    my($query_string);
    if (@ARGV) {
	$input = join(" ",@ARGV);
    } else {
	print STDERR "(offline mode: enter name=value pairs on standard input)\n";
	chomp(@lines = <>); 
	$input = join(" ",@lines);
    }
    $input=~s/\\=/%3D/g;
    $input=~s/\\&/%26/g;
    @words = &shellwords($input);
    if ("@words"=~/=/) {
	$query_string = join('&',@words);
    } else {
	$query_string = join('+',@words);
    }
    return $query_string;
}
END_OF_FUNC
'read_multipart' => <<'END_OF_FUNC',
sub read_multipart {
    my($self,$boundary,$length) = @_;
    my($buffer) = $self->new_MultipartBuffer($boundary,$length);
    return unless $buffer;
    my(%header,$body);
    while (!$buffer->eof) {
	%header = $buffer->readHeader;
	my($key) = $header{'Content-disposition'} ? 'Content-disposition' : 'Content-Disposition';
	my($param)= $header{$key}=~/ name="([^\"]*)"/;
	my($filename) = $header{$key}=~/ filename="(.*)"$/;
	$self->add_parameter($param);
	unless ($filename) {
	    my($value) = $buffer->readBody;
	    push(@{$self->{$param}},$value);
	    next;
	}
	my($tmpfile) = new TempFile;
	open (OUT,">$tmpfile") || die "CGI open of $tmpfile: $!\n";
	$CGI::DefaultClass->binmode(OUT) if $CGI::needs_binmode;
	chmod 0666,$tmpfile;    
	my $data;
	while ($data = $buffer->read) {
	    print OUT $data;
	}
	close OUT;
	my($filehandle);
	if ($filename=~/^[a-zA-Z_]/) {
	    my($frame,$cp)=(1);
	    do { $cp = caller($frame++); } until !eval("$cp->isaCGI()");
	    $filehandle = "$cp\:\:$filename";
	} else {
	    $filehandle = "\:\:$filename";
	}
	open($filehandle,$tmpfile) || die "CGI open of $tmpfile: $!\n";
	$CGI::DefaultClass->binmode($filehandle) if $CGI::needs_binmode;
	push(@{$self->{$param}},$filename);
	$self->{'.tmpfiles'}->{$filename}=$tmpfile;
    }
}
END_OF_FUNC
'tmpFileName' => <<'END_OF_FUNC'
sub tmpFileName {
    my($self,$filename) = self_or_default(@_);
    return $self->{'.tmpfiles'}->{$filename};
}
END_OF_FUNC
);
END_OF_AUTOLOAD
;
package MultipartBuffer;
$FILLUNIT = 1024 * 5;
$TIMEOUT = 10*60;       
$SPIN_LOOP_MAX = 1000;  
$CRLF=$CGI::CRLF;
*MultipartBuffer::AUTOLOAD = \&CGI::AUTOLOAD;
$AUTOLOADED_ROUTINES = '';      
$AUTOLOADED_ROUTINES=<<'END_OF_AUTOLOAD';
%SUBS =  (
'new' => <<'END_OF_FUNC',
sub new {
    my($package,$interface,$boundary,$length,$filehandle) = @_;
    my $IN;
    if ($filehandle) {
	my($package) = caller;
	$IN = $filehandle=~/[':]/ ? $filehandle : "$package\:\:$filehandle"; 
    }
    $IN = "main::STDIN" unless $IN;
    $CGI::DefaultClass->binmode($IN) if $CGI::needs_binmode;
    if ($boundary) {
	$boundary = "--$boundary";
	my($null) = '';
	$length -= $interface->read_from_client($IN,\$null,length($boundary)+2,0);
    } else { 
	my($old);
	($old,$/) = ($/,$CRLF); 
	$boundary = <$IN>;      
	$length -= length($boundary);
	chomp($boundary);               
	$/ = $old;                      
    }
    my $self = {LENGTH=>$length,
		BOUNDARY=>$boundary,
		IN=>$IN,
		INTERFACE=>$interface,
		BUFFER=>'',
	    };
    $FILLUNIT = length($boundary)
	if length($boundary) > $FILLUNIT;
    return bless $self,ref $package || $package;
}
END_OF_FUNC
'readHeader' => <<'END_OF_FUNC',
sub readHeader {
    my($self) = @_;
    my($end);
    my($ok) = 0;
    do {
	$self->fillBuffer($FILLUNIT);
	$ok++ if ($end = index($self->{BUFFER},"${CRLF}${CRLF}")) >= 0;
	$ok++ if $self->{BUFFER} eq '';
	$FILLUNIT *= 2 if length($self->{BUFFER}) >= $FILLUNIT; 
    } until $ok;
    my($header) = substr($self->{BUFFER},0,$end+2);
    substr($self->{BUFFER},0,$end+4) = '';
    my %return;
    while ($header=~/^([\w-]+): (.*)$CRLF/mog) {
	$return{$1}=$2;
    }
    return %return;
}
END_OF_FUNC
'readBody' => <<'END_OF_FUNC',
sub readBody {
    my($self) = @_;
    my($data);
    my($returnval)='';
    while (defined($data = $self->read)) {
	$returnval .= $data;
    }
    return $returnval;
}
END_OF_FUNC
'read' => <<'END_OF_FUNC',
sub read {
    my($self,$bytes) = @_;
    $bytes = $bytes || $FILLUNIT;       
    $self->fillBuffer($bytes);
    my $start = index($self->{BUFFER},$self->{BOUNDARY});
    if ($start == 0) {
	if (index($self->{BUFFER},"$self->{BOUNDARY}--")==0) {
	    $self->{BUFFER}='';
	    $self->{LENGTH}=0;
	    return undef;
	}
	substr($self->{BUFFER},0,length($self->{BOUNDARY})+2)='';
	return undef;
    }
    my $bytesToReturn;    
    if ($start > 0) {           
	$bytesToReturn = $start > $bytes ? $bytes : $start;
    } else {    
	$bytesToReturn = $bytes - (length($self->{BOUNDARY})+1);
    }
    my $returnval=substr($self->{BUFFER},0,$bytesToReturn);
    substr($self->{BUFFER},0,$bytesToReturn)='';
    return ($start > 0) ? substr($returnval,0,-2) : $returnval;
}
END_OF_FUNC
'fillBuffer' => <<'END_OF_FUNC',
sub fillBuffer {
    my($self,$bytes) = @_;
    return unless $self->{LENGTH};
    my($boundaryLength) = length($self->{BOUNDARY});
    my($bufferLength) = length($self->{BUFFER});
    my($bytesToRead) = $bytes - $bufferLength + $boundaryLength + 2;
    $bytesToRead = $self->{LENGTH} if $self->{LENGTH} < $bytesToRead;
    my $bytesRead = $self->{INTERFACE}->read_from_client($self->{IN},
							 \$self->{BUFFER},
							 $bytesToRead,
							 $bufferLength);
    if ($bytesRead == 0) {
	die  "CGI.pm: Server closed socket during multipart read (client aborted?).\n"
	    if ($self->{ZERO_LOOP_COUNTER}++ >= $SPIN_LOOP_MAX);
    } else {
	$self->{ZERO_LOOP_COUNTER}=0;
    }
    $self->{LENGTH} -= $bytesRead;
}
END_OF_FUNC
'eof' => <<'END_OF_FUNC'
sub eof {
    my($self) = @_;
    return 1 if (length($self->{BUFFER}) == 0)
		 && ($self->{LENGTH} <= 0);
}
END_OF_FUNC
);
END_OF_AUTOLOAD
package TempFile;
$SL = $CGI::SL;
unless ($TMPDIRECTORY) {
    @TEMP=("${SL}usr${SL}tmp","${SL}var${SL}tmp","${SL}tmp","${SL}temp","${SL}Temporary Items");
    foreach (@TEMP) {
	do {$TMPDIRECTORY = $_; last} if -d $_ && -w _;
    }
}
$TMPDIRECTORY  = "." unless $TMPDIRECTORY;
$SEQUENCE="CGItemp$$0000";
%OVERLOAD = ('""'=>'as_string');
*TempFile::AUTOLOAD = \&CGI::AUTOLOAD;
sub as_string {
    my($self) = @_;
    return $$self;
}
$AUTOLOADED_ROUTINES = '';      
$AUTOLOADED_ROUTINES=<<'END_OF_AUTOLOAD';
%SUBS = (
'new' => <<'END_OF_FUNC',
sub new {
    my($package) = @_;
    $SEQUENCE++;
    my $directory = "${TMPDIRECTORY}${SL}${SEQUENCE}";
    return bless \$directory;
}
END_OF_FUNC
'DESTROY' => <<'END_OF_FUNC'
sub DESTROY {
    my($self) = @_;
    unlink $$self;              
}
END_OF_FUNC
);
END_OF_AUTOLOAD
package CGI;
if ($^W) {
    $CGI::CGI = '';
    $CGI::CGI=<<EOF;
    $CGI::VERSION;
    $MultipartBuffer::SPIN_LOOP_MAX;
    $MultipartBuffer::CRLF;
    $MultipartBuffer::TIMEOUT;
    $MultipartBuffer::FILLUNIT;
    $TempFile::SEQUENCE;
EOF
    ;
}
$revision;
