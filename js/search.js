jQuery(function($){
	$('table#item_table tbody *').remove();	//全て削除

	$('#keyword').smartenter(function(){
		search();
	});

	//検索
	function search(){
		var value = $('#keyword').val();
		$.post(
			"/portnumbers/data.pl", 
			{"keyword":value},
			function(data, status) {
				$('table#item_table tbody *').remove();	//全て削除
				for(var i=0; i<data.records.length; i++){
					var tr = data.records[i].join('</td><td>');
					$('table#item_table tbody').append("<tr><td>"+tr+"</td></tr>");
				}
				$('#updated').text('Last modified: '+data.updated);
			},
			"json"
		);
	};
});

