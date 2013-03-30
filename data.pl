#!/usr/bin/env perl

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
use LWP::UserAgent;
use HTTP::Request;
use XML::Simple;
use Cache::Memcached::Fast;
use CGI;
use JSON;
use constant URL=>'http://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xml';

# subroutine: get_json
sub get_json
{
	my $data = shift;
	my $keyword = shift;
	my $type = shift;

	my $json = '';
	my @found = ();
	foreach my $d (@{$data->{records}}){
		if($type eq 'by_name'){
			# search by name
			if($d->[0] =~ /$keyword/){
				push(@found, $d)
			}
		}elsif($type eq 'by_no' && $keyword=~/^\d+$/){
			# search by no
			my $no = $d->[1];
			if($no ne '(N/A)'){
				$no =~ s/\s//g;
				if($no =~ /^(\d+)$/){
					# 単一数値
					if($1 == $keyword) { push(@found, $d); }
				}elsif($no =~ /^(\d+)-(\d+)$/){
					# 数値範囲
					if($1 <= $keyword && $keyword <= $2) { push(@found, $d); }
				}
			}
		}
	}
	$json = to_json({'updated'=>$data->{updated}, 'url'=>URL, 'records'=>\@found});
	print $json;
	return($json);
}

# main
my $q = new CGI;
my $keyword = '';
my $type = 'by_name';
foreach my $name ($q->param) {
	if($name eq 'keyword'){
		$keyword = $q->param($name);
	}elsif($name eq 'ktype'){
		$type = $q->param($name);
	}
}
if($keyword eq ''){
	$keyword = shift;   # for Debug
	$type = shift;   # for Debug
}

my $memd = Cache::Memcached::Fast->new({
	servers => [ { address => 'localhost:11211' }],
	namespace => 'portnumbers:',
	utf8 => 1,
});
#$memd->flush_all();	#キャッシュ削除 for Debug

# check modified-date
my $ua = new LWP::UserAgent;
   $ua->agent("LWP::GETHEAD");
my $rq = new HTTP::Request(HEAD => URL);
my $rp = $ua->request($rq);
my $last_modified = $rp->header('Last-Modified');
my %data = ();	# すべてのデータ
my $json = '';

if($last_modified ne $memd->get('Last-Modified')){
	# updated original data
	$memd->flush_all();	# delete cache
	
	$memd->set('Last-Modified', $last_modified);

	my $res = $ua->get(URL);
	my $xml = new XML::Simple;
	my $xdata = $xml->XMLin($res->content);

	$data{updated} = $xdata->{updated};
	$data{records} = ();

	# 枝刈り、memcacheへの保存
	my @hkeys = ('name', 'number', 'protocol');	# description, note は保留
	foreach my $record (@{$xdata->{record}}){
		my @rec = ();
		foreach my $key (@hkeys){
			if(exists($record->{$key})){
				push(@rec, $record->{$key});
			}else{
				if(($key eq 'name') && exists($record->{description})){
					push(@rec, "(".$record->{description}.")");
				}else{
					push(@rec, "(N/A)");
				}
			}
		}
		push(@{$data{records}}, \@rec);
	}

	$memd->set('data', \%data);

	# get_json: search...	
	$json = get_json(\%data, $keyword, $type);
}else{
	# check keyword
	$json = $memd->get("keyword:$type-$keyword");

	if(!$json){
		# search keyword 
		%data = %{$memd->get('data')};
		# get_json: search...
		$json = get_json(\%data, $keyword, $type);
		# save keyword
        $memd->set("keyword:$type-$keyword", $json);
	}
}

# output
print "Content-Type: application/json\n\n";
print $json;
print "\n";

exit;  # end of script
