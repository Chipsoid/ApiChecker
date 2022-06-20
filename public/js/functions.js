function formatMoney(n, c, d, t) {
var n = n, 
    c = isNaN(c = Math.abs(c)) ? 2 : c, 
    d = d == undefined ? "." : d, 
    t = t == undefined ? "," : t, 
    s = n < 0 ? "-" : "", 
    i = parseInt(n = Math.abs(+n || 0).toFixed(c)) + "", 
    j = (j = i.length) > 3 ? j % 3 : 0;
   return s + (j ? i.substr(0, j) + t : "") + i.substr(j).replace(/(\d{3})(?=\d)/g, "$1" + t) + (c ? d + Math.abs(n - i).toFixed(c).slice(2) : "");
 };

$().ready( function() {

    $('button.add-key-form-submit, button.add-user-form-submit, button.add-file-form-submit, button.add-moon-form-submit').on( 'click', function() {
        $('#add-key-form').submit();
    });

    $('.delete_api_key').on( 'click', function() {
        var id = $(this).attr('rel');
        if ( window.confirm('Действительно удалить ключ ' + id + '?') ) {
            $.post( '/api/delete/'+id, function( data ) {
                location.href = '/api/';
            }); 
        }
    });

     $('.delete_user').on( 'click', function() {
        var id = $(this).attr('rel');
        if ( window.confirm('Действительно удалить пользователя ' + id + '?') ) {
            $.post( '/users/delete/'+id, function( data ) {
                location.href = '/users/';
            }); 
        }
    });


    $("#pilot_table").tablesorter({
        theme : 'blue',
     
        sortList : [[0,0]],
     
        // header layout template; {icon} needed for some themes
        headerTemplate : '{content}{icon}',
     
        // initialize column styling of the table
        widgets : ["columns"],
        widgetOptions : {
          // change the default column class names
          // primary is the first column sorted, secondary is the second, etc
          columns : [ "primary", "secondary", "tertiary" ]
        }
    });

    $("#contacts_table").tablesorter({
        theme : 'blue',
     
        sortList : [[0,0]],
     
        // header layout template; {icon} needed for some themes
        headerTemplate : '{content}{icon}',
     
        // initialize column styling of the table
        widgets : ["columns"],
        widgetOptions : {
          // change the default column class names
          // primary is the first column sorted, secondary is the second, etc
          columns : [ "primary", "secondary", "tertiary" ]
        }
    });


    $('#filter_ref_name').on('change', function() {
        var val = $(this).val();
        location.href = val;
    });


    $('ul.assets').on('click', '.assets_node span', function() {
        var loc_id = $(this).parent().attr('rel');
        var id     = $(this).parent().attr('char');
        var contents = $(this).parent().attr('contents') || 0;

        if ( $('.assets_list_'+loc_id).text() == '' ) {
            $.post( '/character/assets_list/'+id+'/'+loc_id+'/'+contents, function( data ) {
                
                $('.assets_list_'+loc_id).html( render_assset_list(data) );
            }); 
        }

        $('.assets_list_'+loc_id).toggleClass('hide').toggleClass('in');
        if ( $('.assets_list_'+loc_id).is(':visible') )
            $(this).find('i').addClass('glyphicon-folder-open').removeClass('glyphicon-folder-close');
        else
            $(this).find('i').addClass('glyphicon-folder-close').removeClass('glyphicon-folder-open');    
    });

    function render_assset_list(data) {
        var str = '';
        for ( i = 0; i < data.length; i++ ) {
            str += '<li';
            if ( data[i]['have_content'] > 0 ) {
                str += ' class="assets_node inner_container" char="'+ data[i]['character_id'] +'" rel="'+ data[i]['item_id'] +'" contents="1">';
                str += '<span><i class="glyphicon glyphicon-folder-close"></i>';
            }
            else {
                str += '>';
            }
            if ( data[i]['icon_path'] )
                str += '<img src="' + data[i]['icon_path'] + '" width="16" height="16" class="asset_image" /> ';
            else
                str += '<img src="/i/types/' + data[i]['type_id']  + '_32.png" width="16" height="16" class="asset_image" /> ';

            str += data[i]['type_name'];

            if (typeof data[i]['is_bpc'] != 'undefined' && data[i]['is_bpc'] == 1 ) {
               str += ' (copy)';
            }
            str += ' <small>x</small>'+data[i]['quantity'];
            if (typeof data[i]['sell_price'] != 'undefined') {
               str += ' <span class="asset_price">';
                if ( data[i]['have_content'] > 0 ) {
                    str += formatMoney(  data[i]['sum_content'], 2 ) + ' ISK</span>';  
                }
                else {
                    str += formatMoney( data[i]['sell_price'], 2 ) + ' ISK</span>';  
                }
            } 
            if ( data[i]['have_content'] > 0 ) {
                str += '</span><ul class="hide assets_list_'+ data[i]['item_id'] +'"></ul>';
            }
            str += '</li>';
        }

        return str;
    }

   // $('.char_info_popover').popover({ html: true, trigger: 'focus' });

    var showPopover = function () {
        $(this).popover('show');
    }
    , hidePopover = function () {
        $(this).popover('hide');
    };

    $('.char_info_popover').popover({
        //content: 'Popover content',
        html: true,
        trigger: 'manual'
    })
    .focus(showPopover)
    .blur(hidePopover)
    .hover(showPopover, hidePopover);

    $('a.show_mail_body').on('click', function() {
        var id    = $(this).attr('rel');
        var from  = $('td.sender_name_'+id).text(); 
        var to    = $('td.to_'+id).text(); 
        var title = $('td.title_'+id).text();
        var body  = $('div.body_'+id).html();

        $('#showMailLabel').text( title );
        $('div.showMailFrom').text( from );
        $('div.showMailTo').text( to );
        $('div.showMailBody').html( body );

    });


    $('a.edit_roles').on('click', function() {
        var id    = $(this).attr('rel');
        var roles = $('td.roles_'+id).text();

        $('#user_id').val(id);
        $('#roles').val(roles);

    });

    $('.add-role-form-submit').on( 'click', function() {
        $('#add-role-form').submit();
    });


    $('#search').on('click', function() {
        $('#search_form').submit();
    });

    $('#reset').on('click', function() {    
        $('#search_form input[type=text]').val('');
        $('#search_form select').val('');
        $('#search_form').submit();
    });

    $('.force_update').on('click', function() {
        if ( ! window.confirm('Точно запустить обновление?') ) { 
            return false; 
        }
    });


    $('.add_to_favorites').on('click', function() {
        var char_id = $(this).attr('rel');
        var star = $(this);
        if ( star.hasClass('glyphicon-star-empty') ) {
            $.post( '/favorites/add/'+char_id, function( data ) {
                star.removeClass('glyphicon-star-empty').addClass('glyphicon-star');
            }); 
        }
        else {
             $.post( '/favorites/del/'+char_id, function( data ) {
                star.removeClass('glyphicon-star-empty').addClass('glyphicon-star-empty');
            }); 
        }
    });

    $('.modify_tag').on('click', function() {
        var char_id = $(this).attr('rel');
        var tag = $(this);
        tag.next().children().toggle('fast');
    });

    $('.modify_bigboy').on('click', function() {
        var char_id = $(this).attr('rel');
        var set_bigboy = $(this).hasClass('grey') ? 1 : 0;
        var char = $(this);
        $.post( '/bigboys/change/'+char_id+'/'+set_bigboy, function( data ) {
            if ( set_bigboy )
                char.removeClass('grey').addClass('black');
            else
                char.removeClass('black').addClass('grey');
        }); 
    });


    $('.open_supers').on('click', function() {
        console.log(char_id);
        var char_id = $(this).attr('rel');
        var is_open = $(this).hasClass('glyphicon-chevron-down') ? 0 : 1;
        var char = $(this);
        if ( is_open ) {
            $('.supers_for_'+char_id).hide();
            char.removeClass('glyphicon-chevron-up').addClass('glyphicon-chevron-down');
        }
        else {
            $('.supers_for_'+char_id).show();
            char.removeClass('glyphicon-chevron-down').addClass('glyphicon-chevron-up');
        }
    });

    $('.change_tag').on('click', function() {
        var char_id = $(this).attr('rel');
        var tag  = $(this);
        var data = $(this).attr('data-content'); 
        var layer = $(this).parent();
        var tag_i = layer.parent().prev();
        $.post( '/tags/change/'+char_id+'/'+data, function( data ) {
            layer.slideUp('fast');
            tag_i.removeClass('grey').removeClass('red').removeClass('green').removeClass('blue').removeClass('purple').addClass(data);
        }); 
    });

    $('body').on( 'click', '.show_contract_body', function() {
        var id    = $(this).attr('rel');
        var char_id = $(this).attr('data-char');
        $.post( '/character/contracts/items/'+char_id+'/'+id, function( data ) {
            $('#showContractLabel').text( data[0][0]['title'] || 'Контракт' );
            $('div.showContractIssuer').text( data[0][0]['issuer_name'] );
            $('div.showContractAssignee').text( data[0][0]['assignee_name'] );
            $('div.showContractAcceptor').text( data[0][0]['acceptor_name'] );
            $('div.showContractType').text( data[0][0]['type'] );
            $('div.showContractIssued').text( data[0][0]['date_issued'] );
            $('div.showContractExpired').text( data[0][0]['date_expired'] );
            $('div.showContractAccepted').text( data[0][0]['date_accepted'] );
            $('div.showContractCompleted').text( data[0][0]['date_completed'] );
            $('div.showContractStartStation').text( data[0][0]['start_station_name'] || data[0][0]['start_location_name'] );
            $('div.showContractEndStation').text( data[0][0]['end_station_name'] || data[0][0]['end_location_name'] );
            $('div.showContractNumDays').text( data[0][0]['num_days'] );
            $('div.showContractPrice').text( data[0][0]['price'] );
            $('div.showContractReward').text( data[0][0]['reward'] );
            $('div.showContractVolume').text( data[0][0]['volume'] );


            $('div.showContractBody').html( render_assset_list( data[1] ) );
            
            //console.log(data);
        });
    });

    $('a.show-ts3-ip-list').on('click', function() {
         var client_id    = $(this).attr('rel');

         $.post( '/ts3/ips/'+client_id, function( data ) {
            $( ".ips_row" ).remove();
            row = '';
            for ( i = 0; i < data.length; i++ ) {
                row += '<tr class="ips_row">';
                row += '<td>' + data[i][0] + '</td>';
                row += '<td>' + data[i][1] + '</td>';
                row += '</tr>';
            }

            $("#user_ips_table tr:first").after(row);
            console.log(data.length);
        });
    });

    $('a.show-forum-ip-list').on('click', function() {
         var client_id    = $(this).attr('rel');

         $.post( '/forum/ips/'+client_id, function( data ) {
            $( ".ips_row" ).remove();
            row = '';
            for ( i = 0; i < data.length; i++ ) {
                row += '<tr class="ips_row">';
                row += '<td>' + data[i][0] + '</td>';
                row += '<td>' + data[i][1] + '</td>';
                row += '</tr>';
            }

            $("#user_ips_table tr:first").after(row);
            console.log(data.length);
        });
    });

    // Поиск лун по имени
    $( "#moon" ).autocomplete({
      source: function( request, response ) {
        $.ajax({
          url: "/starbase/find_moon",
          method: 'POST',
          dataType: "json",
          data: {
            moon_name: request.term
          },
          success: function( data ) {
            console.log(data[0]);
            //response(data);
            response($.map(data, function(item){
                    // return [ item.itemID, item.itemName ];
                    return {
                        value: item.itemID, 
                        label: item.itemName
                    }
                }));
          }
        });
      },
      minLength: 3,
      focus: function( event, ui ) {
        console.log( ui );
        $( "#moon" ).val( ui.item.label );
        return false;
      },
      select: function( event, ui ) {
        $('#moon_id').val(ui.item.value);
        return false;
      },
      open: function() {
        $( this ).removeClass( "ui-corner-all" ).addClass( "ui-corner-top" );
      },
      close: function() {
        $( this ).removeClass( "ui-corner-top" ).addClass( "ui-corner-all" );
      }
    });


    $(document).ready( function() {

        $('select.corp_list_allow').change(function() {
            var corps = $(this).val().join(',');
            var user_id = $(this).attr('data_id');
            var elem = $(this);
            $.post( '/users/corps/'+user_id+'/'+corps, function( data ) {
                elem.effect("highlight", {}, 1000);
            });
        });


    });


});
