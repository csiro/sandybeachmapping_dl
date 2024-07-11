# code to convert masked tile predictions from machine learning (binary segmentation) into polygons (like OSM beaches)
# Julian O'Grady 2024-03-23 
require(terra)
datadir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/ml_outputs/aerial_beach_images_26186025/vic/maskpred/"
datadir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/ml_outputs/aerial_beach_images_26206118/vic/maskpred_all/"

datadir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/ml_outputs/20240408/125542_vic/maskpred_vic_ppb_Y1989_all/"


outdir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/data/maskpred/vic/"

tiffiles = list.files(datadir,full.names="TRUE",pattern = ".tif")

maskpred_r_l = lapply(tiffiles,function(x) rast(x))

maskpred_p_l = lapply(maskpred_r_l,function(x) {x[x == 0] = NA;as.polygons(x)})

maskpred_p = lapply(maskpred_p_l,function(x) project(x,maskpred_p_l[[1]]))

maskpred_p_clean = disagg(aggregate(vect(maskpred_p)))

writeVector(maskpred_p_clean,paste0(outdir,"maskedpred_randomTraningSplit_polygons_all"))

plot(maskpred_p_clean)



