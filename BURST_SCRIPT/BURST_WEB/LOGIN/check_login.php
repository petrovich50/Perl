<?php
session_start(); //Start the session
define(DOC_ROOT,dirname(__FILE__)); // To properly get the config.php file
$username = $_POST['username']; //Set UserName
$password = $_POST['password']; //Set Password
$msg ='';
if(isset($username, $password)) {
    ob_start();
    include(DOC_ROOT.'/config.php'); //Initiate the MySQL connection
    // To protect MySQL injection (more detail about MySQL injection)
    $myusername = stripslashes($username);
    $mypassword = stripslashes($password);
    $myusername = mysqli_real_escape_string($dbC, $myusername);
    $mypassword = mysqli_real_escape_string($dbC, $mypassword);
    $sql="SELECT name FROM clients WHERE login='$myusername' and passwd=ENCODE('$myusername', '$mypassword')";
    $result=mysqli_query($dbC, $sql);
    // Mysql_num_row is counting table row
    $count=mysqli_num_rows($result);
    $row = mysql_fetch_row($result);
    $user_id = $row['name'];
//    echo var_dump($user_od), "<br>";
//    exit (" $count,".DOC_ROOT.", $sql");
//    header("location:login.php");
    // If result matched $myusername and $mypassword, table row must be 1 row
    if($count==1){
        // Register $myusername, $mypassword and redirect to file "admin.php"
//        session_register("admin");
//        session_register("password");
        $_SESSION['admin']=$myusername;
        $_SESSION['password']=$mypassword;
        $_SESSION['name']= $user_id;
        header("location:admin.php");

    }
    else {
        $msg = "Wrong Username or Password. Please retry";
        header("location:login.php?msg=$msg");
    }
    ob_end_flush();
}
else {
    header("location:login.php?msg=Please enter some username and password");
}
?>