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
use LWP::UserAgent;
use HTTP::Request;
use XML::Simple;
use Cache::Memcached::Fast;
use CGI;
use JSON;

# subroutine: get_json
sub get_json
{
	my $data = shift;
	my $keyword = shift;
	my $json = '';
	my @arr = ();
	foreach my $d (@{$data->{records}}){
		if($d->[0] =~ /$keyword/){
			push(@arr, $d)
		}
	}
	$json = to_json(\@arr);	
	return($json);
}

# get keyword
my $q = new CGI;
my $keyword = '';
foreach my $name ($q->param) {
	if($name eq 'keyword'){
		$keyword = $q->param($name);
	}
}
if($keyword eq ''){
	$keyword = shift;   # for Debug
}


my $url = "http://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xml";
my $memd = Cache::Memcached::Fast->new({
	servers => [ { address => 'localhost:11211' }],
	namespace => 'portnumbers:',
	utf8 => 1,
});
#$memd->flush_all();	#キャッシュ削除 for Debug

# check modified-date
my $ua = new LWP::UserAgent;
   $ua->agent("LWP::GETHEAD");
my $rq = new HTTP::Request(HEAD => $url);
my $rp = $ua->request($rq);
my $last_modified = $rp->header('Last-Modified');
my %data = ();	# すべてのデータ
my $json = '';

if($last_modified ne $memd->get('Last-Modified')){
	# updated original data
	$memd->flush_all();	# delete cache
	
	$memd->set('Last-Modified', $last_modified);

	my $res = $ua->get($url);
	my $xml = new XML::Simple;
	my $xdata = $xml->XMLin($res->content);

	$data{title} = $xdata->{title};
	$data{updated} = $xdata->{updated};
	$data{num} = scalar(@{$xdata->{record}});
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
	$json = get_json(\%data, $keyword);
}else{
	# check keyword
	$json = $memd->get('keyword:'.$keyword);

	if(!$json){
		# search keyword 
		%data = %{$memd->get('data')};
		# get_json: search...
		$json = get_json(\%data, $keyword);
		# save keyword
        $memd->set('keyword:'.$keyword, $json);
	}
}

# output
print "Content-Type: application/json\n\n";
print $json;
print "\n";

exit;  # end of script
