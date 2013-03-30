jQuery(function($){
	$('table#item_table tbody *').remove();	//全て削除

	$('#keyword').smartenter(function(){
		search();
	});

	//検索
	function search(){
		var keyword = $('#keyword').val();
		var type = $('input[name="ktype"]:checked').val();
		$.post(
			"/portnumbers/data.pl", 
			{"keyword":keyword, "ktype":type},
			function(data, status) {
				$('table#item_table tbody *').remove();	//全て削除
				$('#updated').empty();
				for(var i=0; i<data.records.length; i++){
					var tr = data.records[i].join('</td><td>');
					$('table#item_table tbody').append("<tr><td>"+tr+"</td></tr>");
				}
				$("#updated").append(
					$("<a></a>").attr("href", data.url).text('Last modified: '+data.updated)
				);
			},
			"json"
		);
	};
});

