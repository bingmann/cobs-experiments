BEGIN{k=0}
{
    print "@k"k;
    print $1;
    print "+";
    for(c=0;c<length($1);c++) printf "X";
    print "";
    k+=1;
}
