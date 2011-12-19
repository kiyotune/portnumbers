#!/usr/bin/perl

#****************************************************************************************************************
#*** http://ja.wikipedia.org/wiki/%E3%83%9D%E3%83%BC%E3%83%88%E7%95%AA%E5%8F%B7
#*** [WELL KNOWN PORT NUMBERS] 0番 - 1023番 ：一般的なポート番号
#*** [REGISTERED PORT NUMBERS] 1024番 - 49151番 ：登録済みポート番号
#*** [DYNAMIC AND/OR PRIVATE PORTS] 49152番 - 65535番 ：自由に使用できるポート番号
#*** ・WELL KNOWN PORT NUMBERは、Internet Assigned Numbers Authority (IANA) が管理
#*** ・REGISTERED PORT NUMBERSに関しては、IANAが利便性を考慮して公開
#*** ・クライアント側に割り当てられるポート番号など、ユーザが自由にポート番号を使用する場合は、49152番以降を使用
#****************************************************************************************************************

use strict;
use warnings;
use Data::Dumper;
use LWP::Simple;
use XML::Simple;
use CGI;

use constant {
	WELL_KNOWN_PORT_NUMBERS => 1023,
	REGISTERED_PORT_NUMBERS => 49151,
	DYNAMIC_PRIVATE_PORTS => 65535,
};

use constant {
	MIN_PORT_NO => 0,
	MAX_PORT_NO => DYNAMIC_PRIVATE_PORTS,
};

my $url = "http://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xml";

#for Debug::start
my $contents = LWP::Simple::get($url);
my $xml = XML::Simple::XMLin($contents);
exists($xml->{record}) or die "can't get xml file www.iana.org";
print "*********************************************************************************************\n";
print "* $url\n";
print "* updated: $xml->{updated}\n";
print "* title: $xml->{title}\n";
print "* id: $xml->{id}\n";
print "*********************************************************************************************\n";
$xml = $xml->{record};
#print Dumper($xml);
exit(0);
#for Debug::end

my $form=new CGI();
print $form->header(-charset=>'UTF-8');	# HTML Header
print $form->start_html(-title=>"ポートNo検索");	# Start of HTML

if($ENV{'REQUEST_METHOD'} eq "GET"){
	#ロード時
	fform("", "");	#検索フォームの表示
}elsif($ENV{'REQUEST_METHOD'} eq "POST"){
	#検索結果の表示
	fform($form->param("port_no") , $form->param("description"), $form->param("empty_port"));	#検索フォームの表示
	if(grep(/empty_port/, $form->param) && $form->param("empty_port")==1){
		#空きポートの表示
		result_table("empty_port", $form->param("port_no"));
	}elsif(grep(/description/, $form->param) && $form->param("description") ne ""){
		#Description
		result_table("description", $form->param("description"));
	}elsif(grep(/port_no/, $form->param) && $form->param("port_no") ne ""){
		#Port No
		result_table("port_no", $form->param("port_no"));
	}
}

print $form->end_html;	# End of HTML
exit(0);



#検索結果
sub result_table{
	my ($type, $value)=($_[0], $_[1]);
	my @detail=split(/\n/, LWP::Simple::get($url));
	#テーブル出力（ヘッダ）
	print << "DISP_TABLE_HEADER";
	<div align="center">
	<table border=1 cellspacing=0 bordercolordark="#ffffff" bordercolor="#777777">
		<tr bgcolor="#cccccc"><th>Port No.</th><th>Protocol</th><th>Description</th></tr>
DISP_TABLE_HEADER
	my @port_no_list=();
	foreach (@detail){
		if(/last updated (\d+\-\d+\-\d+)/){
			print("<a href=$url>The data updated to $1 is used. </a><br>\n");
		}elsif(/(\w*)\s+(\d+)\/(\w+)\s+(.+)/){
			my ($keyword, $port_no, $protocol, $description) = ($1, $2, $3, $4);
			my $fdisp=0;
			if($keyword ne ""){
				$description="[ $keyword ] $description";
			}
			if($value eq "__ALL__"){
				$fdisp=1;
			}else{
				if($type eq "empty_port"){
					push(@port_no_list, $port_no);
				}elsif($type eq "port_no"){
					if($port_no==$value){ $fdisp=1; }
				}elsif($type eq "description"){
					if($description=~/$value/i){ $fdisp=1; }
				}
			}
			#表示
			if($fdisp==1){
				print("<tr>".td_port_type($port_no)."<td>$protocol</td><td>$description</td>\n");
			}
		}
	}
	if($type eq "empty_port"){
		#空きポート表示
		my %h_port_no_list=();
		@h_port_no_list{@port_no_list}=1;
		@port_no_list=sort {$a <=> $b} @port_no_list;	#値の昇順でソート
		my ($i, $from, $to);
		$from=$to=-1;
		if($value ne ""){
			#指定のポートNoが空きポートかどうか調べる
			if(!exists($h_port_no_list{$value})){
				print("<tr>".td_port_type($value)."<td colspan=2>(Empty)</td>\n");
			}else{
				print("<tr>".td_port_type($value)."<td colspan=2>(Reserved) take the checkmark off 'Empty port' to see description.</td>\n");
			}
		}else{
			#一覧表示
			for ($i=MIN_PORT_NO; $i<=$port_no_list[$#port_no_list]; $i++){
				if(!exists($h_port_no_list{$i})){
					if($from==-1){ $from=$i; }
					else{ $to=$i; }
				}else{
					if($from!=-1){
						if($to!=-1){
							print("<tr>".td_port_type($from, "$from - $to")."<td colspan=2><br></td>\n");
						}else{
							print("<tr>".td_port_type($from)."<td colspan=2><br></td>\n");
						}
						$from=$to=-1;
					}
				}
			}
			if($port_no_list[$#port_no_list]<REGISTERED_PORT_NUMBERS){
				$from=$port_no_list[$#port_no_list]+1;
				$to=REGISTERED_PORT_NUMBERS;
				if($from==$to){
					print("<tr>".td_port_type($from)."<td colspan=2><br></td>\n");
				}else{
					print("<tr>".td_port_type($from, "$from - $to")."<td colspan=2><br></td>\n");
				}
			}
		}
	}
	print "</table></div>\n";	# TABLE_FOOTER
}

#検索フォームの表示
sub fform{
	my $chk_empty="";
	if($_[2]){ $chk_empty="checked"; }

	print << "DISP_FIND_FORM_END";
	<form action="index.pl" method="post" name="find_portno">
		<table align="center">
			<tr>
				<td align="right">Port no.</td><td align="left"><input type="text" name="port_no" size=20 value="$_[0]"></td>
				<td align="right">Description</td><td align="left"><input type="text" name="description" size=20 value="$_[1]"></td>
				<td align="right">Empty port</td><td align="left"><input type="checkbox" name="empty_port" value="1" $chk_empty></td>
				<td><input type="submit" name="btn_submit" value="Find"></td>
			</tr>
		</table>
	</form>
DISP_FIND_FORM_END

	#色凡例
	&td_color_sample;
}

#ポートの種類毎のセル色分け
sub td_port_type{
	my ($port_no, $text) = @_;

	my $color='lightgray';
	if(MIN_PORT_NO <= $port_no && $port_no <= WELL_KNOWN_PORT_NUMBERS){
		$color='lightcoral';
	}elsif(WELL_KNOWN_PORT_NUMBERS + 1<= $port_no && $port_no <= REGISTERED_PORT_NUMBERS){
		$color='lightseagreen';
	}elsif(REGISTERED_PORT_NUMBERS + 1<= $port_no && $port_no <= DYNAMIC_PRIVATE_PORTS){
		$color='khaki';
	}else{
		$port_no="(out of range)";
	}

	if($text ne ""){
		$port_no=$text;
	}

	return("<th align=center bgcolor=$color>$port_no</th>\n");
}

#色凡例
sub td_color_sample{
	my $td="";
	$td.="<table align=center border=0 cellpadding=0><tr>";
	$td.="<td align=rignt>color legend：</td>\n";
	$td.=&td_port_type(WELL_KNOWN_PORT_NUMBERS, 'Well known port numbers.<br>'.MIN_PORT_NO.' - '.WELL_KNOWN_PORT_NUMBERS);
	$td.=&td_port_type(REGISTERED_PORT_NUMBERS, 'Registered port numbers.<br>'.(WELL_KNOWN_PORT_NUMBERS+1).' - '.REGISTERED_PORT_NUMBERS);
	$td.=&td_port_type(DYNAMIC_PRIVATE_PORTS, 'Dynamic private ports.<br>'.(REGISTERED_PORT_NUMBERS+1).' - '.DYNAMIC_PRIVATE_PORTS);
	$td.=&td_port_type(MAX_PORT_NO+1, 'out of range');
	$td.="</tr></table>\n";
	print($td);
}
