<?php
session_start(); //Start the session
define(ADMIN,$_SESSION['name']); //Get the user name from the previously registered super global variable
echo var_dump($_SESSION['name']), " HHHHH";
if(!isset($_SESSION['admin'])) { //If session not registered
header("location:login.php"); // Redirect to login.php page

} else {//Continue to current page
header( 'Content-Type: text/html; charset=utf-8' );
}
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
    <title>Welcome To Admin Page Demonstration</title>
</head>
<body>
    <h1>Welcome To Admin Page <?php echo ADMIN /*Echo the username */ ?></h1>
    <p><a href="logout.php">Logout</a></p> <!-- A link for the logout page -->
    <p>Put Admin Contents</p>
    <DIV id="client-lafon" class="client">
    <P><SPAN class="client-title">Client Section:</SPAN>
    <TABLE class="client-data">
    <TR><TH>Last name:<TD>Lafon</TR>
    <TR><TH>First name:<TD>Yves</TR>
    <TR><TH>Tel:<TD>(617) 555-1212</TR>
    <TR><TH>Email:<TD>yves@coucou.com</TR>
    </TABLE>
    </DIV>
    <DIV id="client-lafon" class="client">
    <P><SPAN class="client-title">INTERFACES TO TIE TO THE CURRENT CLIENT:</SPAN>
    <TABLE class="client-data">
    <TR><TH>Last name:<TD>Lafon</TR>
    <TR><TH>First name:<TD>Yves</TR>
    <TR><TH>Tel:<TD>(617) 555-1212</TR>
    <TR><TH>Email:<TD>yves@coucou.com</TR>
    </TABLE>
    </DIV>
</body>
</html>