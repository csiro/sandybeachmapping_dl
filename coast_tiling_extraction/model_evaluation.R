# code to evaluate MLA
# Julian O'Grady 2024-04-22 
require(terra)

require(OpenStreetMap)
require(raster)

datadir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/data/"
#old data 
vicdir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/ml_outputs/20240408/125542_vic/"
nswdir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/ml_outputs/20240408/130503_nsw/"
MLA_vicTrain_vicPred = vect(paste0(vicdir,"maskpred_all_polygons.shp.zip"))
MLA_nswTrain_vicPred = vect(paste0(nswdir,"maskpred_vic_all_polygons.shp.zip"))
MLA_nswTrain_nswPred = vect(paste0(nswdir,"maskpred_all_polygons.shp.zip"))
MLA_vicTrain_nswPred = vect(paste0(vicdir,"maskpred_nsw_all_polygons.shp.zip"))

#new data
vicdir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/ml_outputs/20240419/130359_vic/"
nswdir = "/datasets/work/ev-coastal-ml/work/Beach_mapping/ml_outputs/20240423/151140_nsw/"
MLA_vicTrain_vicPred = vect(paste0(vicdir,"maskpred_vic_all_polygons.shp.zip"))
MLA_nswTrain_vicPred = vect(paste0(nswdir,"maskpred_vic_all_polygons.shp.zip"))
MLA_nswTrain_nswPred = vect(paste0(nswdir,"maskpred_nsw_all_polygons.shp.zip"))
MLA_vicTrain_nswPred = vect(paste0(vicdir,"maskpred_nsw_all_polygons.shp.zip"))



OSMBeachShapes_vic = unique(vect(paste0(datadir,"OSM_overpass_student_beach_polygons/Shorts_beaches_CoastSat_OSMBeach_"
                                ,"vic",".geojson")))

OSMBeachShapes_nsw = unique(vect(paste0(datadir,"OSM_overpass_student_beach_polygons/Shorts_beaches_CoastSat_OSMBeach_"
                                ,"nsw",".geojson")))


#Buscombe, D. and Goldstein, E.B. (2022) ‘A Reproducible and Reusable Pipeline for Segmentation of Geoscientific Imagery’, Earth and Space Science, 9(9), pp. 1–11. Available at: https://doi.org/10.1029/2022EA002332.
#https://www.v7labs.com/blog/intersection-over-union-guide

Y = OSMBeachShapes_vic #true labeled
Yhat = disagg(project(MLA_vicTrain_vicPred,Y)) #MLA predicted


IoUf = function(Y,Yhat,plotit=FALSE) {
   YnYhat_idx = relate(Y,Yhat,"intersects",pairs=TRUE)
   ixs = unique(YnYhat_idx[,1])
   ni = length(ixs)
   IoU = array(dim = c(ni,4))
   for(ix in 1:ni){
       c1i = which(YnYhat_idx[,1] == ixs[ix])
       Yi = buffer(Y[YnYhat_idx[c1i[1],1]],0)
       Yhati = buffer(aggregate(Yhat[YnYhat_idx[c1i,2]]),0)
       YnYhati = aggregate(intersect(Yi,Yhati))
       YuYhati = aggregate(union(Yi,Yhati))
       if(plotit){
         ext_txt = paste(ext(buffer(Yi,2)))
         ext_txt = substr(ext_txt,5,nchar(ext_txt)-1)
         tile_ext = as.numeric(strsplit(ext_txt,",")[[1]])

         #download tile image from extent
         mp <- openmap(c(tile_ext[4],tile_ext[1]),c(tile_ext[3],tile_ext[2]),type="bing")
         r = rast(raster(mp))
         r = project(r,crs(Y))

         extall = terra::ext(YuYhati)
         alpha = 0.5       
         p1 = rbind(Yi,Yhati)
         p1$name = c("Y","Yhat")
         plotRGB(r,mar = c(0,0,4,3),main=expression(Y~~hat(Y)))
         plot(p1,"name",col = c(2,4),alpha=alpha,,sort = p1$name,add=TRUE)        
         p1 = rbind(YnYhati,YuYhati)
         p1$name = c("YnYhat","YuYhat")
         plotRGB(r,mar = c(0,0,4,3),main="IoU")
         plot(p1,"name",col = c(2,4),alpha=alpha,sort = p1$name,add=TRUE)       
         p1 = rbind(YnYhati,Yi)
         p1$name = c("YnYhat","Y")
         plotRGB(r,mar = c(0,0,4,3),main="IoY")
         plot(p1,"name",col = c(2,4),alpha=alpha,sort = p1$name,add=TRUE)       
         p1 = rbind(YnYhati,Yhati)
         p1$name = c("YnYhat","Yhat")
         plotRGB(r,mar = c(0,0,4,3),main=expression(Io*hat(Y)))
         plot(p1,"name",col = c(2,4),alpha=alpha,sort = p1$name,add=TRUE)       
        }
       IoU[ix,1] = as.numeric(Yi$osm_id)
       IoU[ix,2] = as.numeric(expanse(YnYhati)/expanse(YuYhati))
       IoU[ix,3] = as.numeric(expanse(YnYhati)/expanse(Yi))
       IoU[ix,4] = as.numeric(expanse(Yhati)/expanse(Yi))
       
    }
    IoUdf = as.data.frame(IoU)
    names(IoUdf) = c("osm_id","IoU","IoY","IoYhat")
    return(IoUdf)
}
par(mfrow = c(1,4))

#plot example beaches
j=46
IoUf(Y=OSMBeachShapes_nsw[j],Yhat=disagg(project(MLA_nswTrain_nswPred,Y)),plotit=TRUE)

#compute the statistics
MLA_vicTrain_vicPred_IoU = IoUf(Y=OSMBeachShapes_vic,Yhat=disagg(project(MLA_vicTrain_vicPred,Y)))
MLA_nswTrain_vicPred_IoU = IoUf(Y=OSMBeachShapes_vic,Yhat=disagg(project(MLA_nswTrain_vicPred,Y)))
MLA_vicTrain_nswPred_IoU = IoUf(Y=OSMBeachShapes_nsw,Yhat=disagg(project(MLA_vicTrain_nswPred,Y)))
MLA_nswTrain_nswPred_IoU = IoUf(Y=OSMBeachShapes_nsw,Yhat=disagg(project(MLA_nswTrain_nswPred,Y)))

tabstats = c("nTrain","nPred","ATrain","APred","meanIoC","meanIoY","meanIoYhat","medianIoC","medianIoY","medianIoYhat")
sumtab = data.frame(varbs = tabstats)

retStats = function(Y,Yhat,MLA)
   c(length(Y),length(Yhat), sum(expanse(Y))/1e6,sum(expanse(Yhat))/1e6,apply(MLA,2,mean)[2:4],apply(MLA,2,median)[2:4])

sumtab$VICTrain_VICPred = retStats(Y=OSMBeachShapes_vic,Yhat=disagg(project(MLA_vicTrain_vicPred,Y)),MLA_vicTrain_vicPred_IoU)
sumtab$NSWTrain_VICPred = retStats(Y=OSMBeachShapes_nsw,Yhat=disagg(project(MLA_nswTrain_vicPred,Y)),MLA_nswTrain_vicPred_IoU)
sumtab$NSWTrain_NSWPred = retStats(Y=OSMBeachShapes_nsw,Yhat=disagg(project(MLA_nswTrain_nswPred,Y)),MLA_nswTrain_nswPred_IoU)
sumtab$VICTrain_NSWPred = retStats(Y=OSMBeachShapes_vic,Yhat=disagg(project(MLA_vicTrain_nswPred,Y)),MLA_vicTrain_nswPred_IoU)

write.csv(sumtab, file = paste(datadir,"ml_vic_vs_nsw_stats_v2.csv"))

sumtab$VICTrain_VICPred = c(length(OSMBeachShapes_vic),sum(expanse(OSMBeachShapes_vic))/1e6,length(disagg(MLA_vicTrain_vicPred)),expanse(MLA_vicTrain_vicPred)/1e6,
,apply(MLA_vicTrain_vicPred_IoU,2,mean)[2:4],apply(MLA_vicTrain_vicPred_IoU,2,median)[2:4])



#plot stats 
bw=0.01
par(mfcol = c(2,3))
plot(density(MLA_vicTrain_vicPred_IoU$IoU,bw = bw),col="navyblue",xlim = c(0,1),ylim = c(0,5),main = "IoU");grid()
legend("topleft",c("MLA_vicTrain_vicPred","MLA_nswTrain_vicPred"),col = "navyblue",lty = c(1,2))
lines(density(MLA_nswTrain_vicPred_IoU$IoU,bw = bw),col="navyblue",lty=2)
plot(density(MLA_nswTrain_nswPred_IoU$IoU,bw = bw),col="lightblue",xlim = c(0,1),ylim = c(0,5),main = "IoU");grid()
legend("topleft",c("MLA_nswTrain_nswPred","MLA_vicTrain_nswPred"),col = "lightblue",lty = c(1,2))
lines(density(MLA_vicTrain_nswPred_IoU$IoU,bw = bw),col="lightblue",lty=2)

plot(density(MLA_vicTrain_vicPred_IoU$IoY,bw = bw),col="navyblue",xlim = c(0,1),ylim = c(0,10),main = "IoY");grid()
lines(density(MLA_nswTrain_vicPred_IoU$IoY,bw = bw),col="navyblue",lty=2)
plot(density(MLA_nswTrain_nswPred_IoU$IoY,bw = bw),col="lightblue",xlim = c(0,1),ylim = c(0,10),main = "IoY");grid()
lines(density(MLA_vicTrain_nswPred_IoU$IoY,bw = bw),col="lightblue",lty=2)

plot(density(MLA_vicTrain_vicPred_IoU$IoYhat,bw = bw),col="navyblue",xlim = c(0,2),ylim = c(0,20),main = expression(Io*hat(Y)));grid()
lines(density(MLA_nswTrain_vicPred_IoU$IoYhat,bw = bw),col="navyblue",lty=2)
plot(density(MLA_nswTrain_nswPred_IoU$IoYhat,bw = bw),col="lightblue",xlim = c(0,2),ylim = c(0,20),main = expression(Io*hat(Y)));grid()
lines(density(MLA_vicTrain_nswPred_IoU$IoYhat,bw = bw),col="lightblue",lty=2)



par(mfcol = c(2,3))
plot(ecdf(MLA_vicTrain_vicPred_IoU$IoU),col="navyblue",xlim = c(0,1),main = "IoU",do.points = FALSE);grid()
lines(ecdf(MLA_nswTrain_vicPred_IoU$IoU),col="navyblue",lwd=2,do.points = FALSE)
plot(ecdf(MLA_nswTrain_nswPred_IoU$IoU),col="lightblue",xlim = c(0,1),main = "IoU",do.points = FALSE);grid()
lines(ecdf(MLA_vicTrain_nswPred_IoU$IoU),col="lightblue",lwd=2)

plot(ecdf(MLA_vicTrain_vicPred_IoU$IoY),col="navyblue",xlim = c(0,1),main = "IoY",do.points = FALSE);grid()
lines(ecdf(MLA_nswTrain_vicPred_IoU$IoY),col="navyblue",lwd=2)
plot(ecdf(MLA_nswTrain_nswPred_IoU$IoY),col="lightblue",xlim = c(0,1),main = "IoY",do.points = FALSE);grid()
lines(ecdf(MLA_vicTrain_nswPred_IoU$IoY),col="lightblue",lwd=2)

plot(ecdf(MLA_vicTrain_vicPred_IoU$IoYhat),col="navyblue",xlim = c(0,2),main = expression(Io*hat(Y)),do.points = FALSE);grid()
legend("topleft",c("MLA_vicTrain_vicPred","MLA_nswTrain_vicPred"),col = "navyblue",lwd = c(1,2))
lines(ecdf(MLA_nswTrain_vicPred_IoU$IoYhat),col="navyblue",lwd=2)
plot(ecdf(MLA_nswTrain_nswPred_IoU$IoYhat),col="lightblue",xlim = c(0,2),main = expression(Io*hat(Y)),do.points = FALSE);grid()
legend("topleft",c("MLA_nswTrain_nswPred","MLA_vicTrain_nswPred"),col = "lightblue",lwd = c(1,2))
lines(ecdf(MLA_vicTrain_nswPred_IoU$IoYhat),col="lightblue",lwd=2)







