#!/usr/bin/perl

#use strict;

#use English;
use Persistent::DBM;
use Persistent::File;

eval {
    my $openTrades = new Persistent::File('/tmp/trades.txt');

    $openTrades->add_attribute('id', 'id', 'Number', undef, 2);
    $openTrades->add_attribute('numtrades', 'persistent', 'Number', undef, 2);
    $openTrades->add_attribute('islive', 'persistent', 'Number', undef, 2);
    $openTrades->add_attribute('ordid', 'persistent', 'Number', undef, 20);
    $openTrades->add_attribute('ordsym', 'persistent', 'String', undef, 10);
    $openTrades->add_attribute('ordtyp', 'persistent', 'String', undef, 4);
    $openTrades->add_attribute('ordlot', 'persistent', 'String', undef, 5);
    $openTrades->add_attribute('ordprice', 'persistent', 'String', undef, 10);
    $openTrades->add_attribute('ordsl', 'persistent', 'String', undef, 10);
    $openTrades->add_attribute('ordtp', 'persistent', 'String', undef, 10);





    $openTrades->restore_all();
    
    #if ( $openTrades->numtrades !=""  ) { # csak akkor kezd bele a while-ba ha van valami egyáltalán az adattáblában :)


    print " ";
    while ( $openTrades->restore_next()  ) 
    {
	my $href = $openTrades->data();
	# A kiirashoz mehetne meg egy ellenorzes. Egy sort csak akkor adjon vissza, ha az islive !=0!
	
	if ($href->{'islive'} !=0 ) 
	{
	    print $href->{'ordid'}.",";
	    print $href->{'ordsym'}.",";
	    print $href->{'ordtyp'}.",";
	    print $href->{'ordlot'}.",";
	    print $href->{'ordprice'}.",";
	    print $href->{'ordsl'}.",";
	    print $href->{'ordtp'}."";
	} 



	
	print "|";
    }
     
    
    # DEBUG
    #open FILE, ">> /tmp/file.txt" or die $!;
    #print FILE "ez az \n";
    #close FILE;
    #} 

};

if ($EVAL_ERROR) {  ### catch those exceptions! ###
    print "An error occurred: $EVAL_ERROR\n";
    
}
1