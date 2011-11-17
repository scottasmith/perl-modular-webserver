
function checkAllUsers()
{
	if( $('#selectall').attr('checked') ) {
		$('input[name="pid"]').each(function(){
		    $(this).attr('checked', true);
		});
	}
	else {
		$('input[name="pid"]').each(function(){
		    $(this).attr('checked', false);
		});
	}
}

function setup_perm_users_add()
{
	var user = prompt("Username");
	var has_user = false;

	$('select[name="perm_users"]>option').each(function(){
	    if( $(this).val() == user ) {
		has_user = true;
	    }
	});

	if( has_user == false ) {
	    $('select[name="perm_users"]').append('<option value="' + user + '">' + user + '</option>');
	}
	else {
	    alert("User already added");
	}
}

function setup_perm_users_del()
{
	$('select[name="perm_users"] :selected').remove();
}

