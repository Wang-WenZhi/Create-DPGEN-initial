use strict;
use Math::Trig;
use warnings;
use Cwd;
use List::Util qw/sum/;
###----------Enter initial data element----------
my $currentPath = getcwd();
my @myelement = sort ("Cr","Cu","Ni","Si","Zn"); #!!!
my $myelement = join ('',@myelement);
my %myelement;
for (my $ii=1; $ii<=@myelement; $ii++){
    my $rr = $ii-1;
    $myelement{$myelement[$rr]}= $ii;
    print "$ii";
} ###If DPGEN element*N
###----------Find sout-----------
my $out_file = `find $currentPath/$myelement/scf -maxdepth 2 -name "*.sout"`;#!!!
# my $out_files = `find $currentPath/$myelement/scf -maxdepth 2 -name "*.in"`;
my @out_file = split("\n", $out_file);
# my @out_files = split("\n", $out_files);
@out_file = sort @out_file;
# @out_files = sort @out_files;
# print "@out_file\n";
my @out_filepath = map (($_ =~ m/(.*)\/.*.sout$/gm),@out_file);
my @out_filename = map (($_ =~ m/.*\/(.*).sout$/gm),@out_file);

# print "@out_filepath";
# print "@out_filename\n";

my $running = `squeue -o \%j | awk 'NR!=1'`;
my @running = split("\n",$running);
my %running;
for(@running){
    $running{$_} = 1;
}
###----------Find type.raw Yes or No-----------
my $out_data = `find $currentPath/$myelement/scf -maxdepth 2 -name "dpE2expE.dat"`;#!!!
my @out_data = split("\n", $out_data);
@out_data = sort @out_data;
my @data_filename = map (($_ =~ m/dpE2expE.dat$/gm),@out_data);
my %data_filename;
for(@data_filename){
    $data_filename{$_} = 1;
}
###-----------------------------------------------
for my $id (0..$#out_file){
    # my $done = `grep -o -a 'DONE' $out_file[$id]`; 
    # print "$out_file[$id]";
    
    # if($done ne "DONE" ||  exists $running{$out_filename[$id]} || exists $data_filename{$out_filename[$id]} ){
    #     next;
    # }
   # print "$out_file[$id]";
    print "$out_filename[$id]\n";
open my $all ,"< $out_file[$id]";
# print "$out_file[$id]";
my @all = <$all>;
close($all);
my $natom = `cat $out_file[$id]|sed -n '/number of atoms\\/cell/p' | sed -n '\$p'| awk '{print \$5}'`;
chomp $natom;
# print"$natom";
if(!$natom){die "You don't get the Atom Number!!!\n $out_file[$id]";}

open my $data ,"> $out_filepath[$id]/dpE2expE.dat";

my $element = `cat $out_file[$id] | sed -n -r '/^\\s+[A-Z]{1}[a-z]{0,1}\\s+[0-9]+.[0-9]+\\s+/p' |awk '{print \$1}' | sort | uniq `;
# print"$element";
#  print "$out_file[$id]";
my @element = split("\n",$element);
@element =  sort @element;

my %element;
for (my $i=1; $i<=@element; $i++){
    my $r = $i-1;
    $element{$element[$r]}= $i;
    # print "$i";
}

#----------Cut Atom ID------------
my @coord = grep {if(m/^\s+\d*\s+([A-Z]{1}[a-z]{0,1})\s+tau\(\s+\d*\)\s+=\s+\(\s+[+-]?\d*.\d*\s+[+-]?\d*.\d*\s+[+-]?\d*.\d*\s+\)/gm){
$_ = [$1];}} reverse @all;

my @atomss = (1..$natom); #Atom number
# print "@atomss";

###-----------Enter QECohesiveEnergy----------------
my @QECohesiveEnergy = ("-175.48997499", "-403.78549009", "-343.28297981", "-11.38216783", "-461.55494226");# !!!Ag(-287.332112) Ge(-213.647798905) Mn(-211.20344754) Sb(-184.9542459) Te(-26.49388414)  Rydberg Constant
###-----------Calculate QECohesiveEnergy------------
my $sumQECohesiveEnergy = 0;
# my @qwe = @QECohesiveEnergy[$element{$coord[-$_][0]}-1] for @atomss;
# print "@qwe";
$sumQECohesiveEnergy += @QECohesiveEnergy[$element{$coord[-$_][0]}-1] for @atomss;#Rydberg Constant
my $sumQECohesiveEnergyeV = $sumQECohesiveEnergy*13.6056980659;#eV
###----------Calculate QEdftBEi--------------------
my $QEdftBEi = $sumQECohesiveEnergyeV/$natom;
###------------------------------------------------
print $data "#DFT binding energy summation (eV): sum(dftBEi* atomNoi)->$QEdftBEi*$natom\n";
print $data "dftBE_all = $sumQECohesiveEnergyeV\n";#eV
###-----------Enter CohesiveEnergy----------------
my @CohesiveEnergy = ("-4.10", "-3.49", "-4.44", "-4.63", "-1.35");# !!!Ag(-2.95) Ge(-3.85) Mn(-2.92) Sb(-2.75) Te(-2.19) eV/atom
###-----------Calculate CohesiveEnergy------------
my $sumCohesiveEnergy = 0;
$sumCohesiveEnergy += @CohesiveEnergy[$element{$coord[-$_][0]}-1] for @atomss;
###----------Calculate dftBEi---------------------
my $expdftBEi = $sumCohesiveEnergy/$natom;
###-----------------------------------------------
print $data "#exp binding energy summation (eV): sum(BEi* atomNoi)-> $expdftBEi*$natom\n";
print $data "expBE_be = $sumCohesiveEnergy\n"; #eV
###----------elements.dat-------------------------
open my $element_data ,"> $out_filepath[$id]/elements.dat";
print $element_data "#as the format of type.raw, mainly for DFT input\n";
for(1..$natom){
print $element_data "$coord[-$_][0] ";
}
###----------masses.dat---------------------------
open my $masses_data ,"> $out_filepath[$id]/masses.dat";
print $masses_data "#need to set masses in a column formate\n";
# my $mass = `cat $out_file[$id] | sed -n -r '/^\\s+[A-Z]{1}[a-z]{0,1}\\s+[0-9]+.[0-9]+\\s+/p' |awk '{print \$3}' |  uniq `;
# my @mass = split("\n",$mass);
my @mass_coord = grep {if(m/^\s+[A-Z]{1}[a-z]{0,1}\s+[+-]?\d+.\d+\s+([+-?]\d*.\d*)\s+[A-Z]{1}[a-z]{0,1}\(\s+[+-]?\d*.\d*\)/gm){
$_ = [$1];}} reverse @all;
for (0..$#element){
    my $i = $_+1;
print  $masses_data  "$mass_coord[-$_][0]\n";
}
###----------type.raw-----------------------------
# open my $type_data ,"> $out_filepath[$id]/type.raw";
# for (1..$natom){
#     my $elementID = $element{$coord[-$_][0]}-1;
#     print $type_data  "$elementID ";
# }
###----------If DPGEN element*N type.raw-----------------------------
open my $type_data ,"> $out_filepath[$id]/type.raw";
for (1..$natom){
    my $elementID = $myelement{$coord[-$_][0]}-1;
    print $type_data  "$elementID ";
}
###-----------------------------------------------
}