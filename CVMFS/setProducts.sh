#!/bin/bash

#Set the PRODUCTS variable to avoid pulling down duplicate products with pullProducts
#source /grid/fermiapp/products/larsoft/setup
#source /grid/fermiapp/products/sbnd/setup
#source /grid/fermiapp/products/artdaq/setup
#source /grid/fermiapp/products/common/etc/setup
source /cvmfs/larsoft.opensciencegrid.org/products/setup_larsoft.sh
source /cvmfs/sbn.opensciencegrid.org/products/sbn/setup
source /cvmfs/fermilab.opensciencegrid.org/products/artdaq/setup
source /cvmfs/fermilab.opensciencegrid.org/products/common/etc/setup
echo $PRODUCTS
