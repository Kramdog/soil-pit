# Load existing veg data from site table
setwd("G:/workspace/speciesDistributionModeling")
sites.df <- read.csv("sites.csv")
sitesYUBR.df <- read.csv("sitesYUBR.csv")

# Prep data
library(plyr)
library(car)
yubr.df <- join(sites.df, sitesYUBR.df, by="User.Site.ID")
yubr.df <- subset(yubr.df, select=c(User.Site.ID, UTM.Easting, UTM.Northing, Plant.Symbol))
yubr.df$Plant.Symbol <- as.numeric(yubr.df$Plant.Symbol)
yubr.df[is.na(yubr.df)] <- 0 
yubr.df$Plant.Symbol <- as.factor(yubr.df$Plant.Symbol)
levels(yubr.df$Plant.Symbol) <- c("NOYUBR", "YUBR")

# Load geodata
library(sp)
yubr.sp <- yubr.df
coordinates(yubr.sp) <- ~ UTM.Easting+UTM.Northing
proj4string(yubr.sp)<- ("+init=epsg:26911")

library(raster)
setwd("G:/workspace/soilTemperatureMonitoring/geodata")

r.crs <- CRS("+init=epsg:26911")

sg <- raster("ned60m_deserts_sgp5ev.sdat", crs=r.crs)
srcv <- raster("ned60m_deserts_srcv.sdat", crs=r.crs)
no <- raster("ned60m_deserts_nopen.sdat", crs=r.crs)
po <- raster("ned60m_deserts_popen.sdat", crs=r.crs)
twi <- raster("ned60m_deserts_twi.sdat", crs=r.crs)
tc1 <- raster("landsat60m_deserts_tc1avg.sdat", crs=r.crs)
tc2 <- raster("landsat60m_deserts_tc2avg.sdat", crs=r.crs)
tc3 <- raster("landsat60m_deserts_tc3avg.sdat", crs=r.crs)
temp1 <- raster("prism30as_deserts_tavg_1981_2010_annual_C.sdat", crs=r.crs
precip1 <- raster("prism30as_deserts_ppt_1981_2010_annual_mm.sdat", crs=r.crs)
temp2 <- raster("prism30as_deserts_tavg_1981_2010_dif_C.sdat", crs=CRS("+init=epsg:26911"))
precip2 <- raster("prism30as_deserts_ppt_1981_2010_dif_mm.sdat", crs=r.crs
mast <- raster("mast.raster2.new.tif", crs=r.crs)

geodata <- stack(sg, twi, po, no, srcv, tc1, tc2, tc3, temp1, precip1, temp2, precip2, mast)
names(geodata) <- c("sg","twi","po", "no", "srcv","tc1","tc2","tc3","temp1","precip1","temp2","precip2","mast")

# Join YUBR and geodata
setwd("G:/workspace/speciesDistributionModeling")
geoinfoYUBR <- extract(geodata,yubr.sp)
geoinfoYUBR <- as.data.frame(geoinfoYUBR)
data <- cbind(yubr.df,geoinfoYUBR)

# Compute multivariate mean of YUBR presense
test <- subset(data, Plant.Symbol == 'YUBR')
test <- na.exclude(test)
test2 <- as.data.frame(cbind("Modal", 0, 0, "YUBR"))
test3 <- as.data.frame(rbind(apply(test[,5:18],2,mean)))
test4 <- cbind(test2,test3)
names(test4) <- names(test)
test5 <- rbind(data,test4)

# Compute geometric distance from multivariate mean of YUBR presense
library(cluster)
yubr.dist <- daisy(test5[,5:18], stand=T)
yubr.m <- as.matrix(yubr.dist)
yubr.d <- yubr.m[nrow(test5),1:nrow(test5)-1]
yubr.df2 <- cbind(data,yubr.d)

# Exploratory analysis
pairs(yubr.df2[,c(5:12,19)], panel=panel.smooth, diag.panel=panel.hist, upper.panel=panel.cor)
pairs(yubr.df2[,c(13:19)], panel=panel.smooth, diag.panel=panel.hist, upper.panel=panel.cor)
round(cor(yubr.df2),2)

# Create model using regression splines
yubr.full <- lm(yubr.d ~ ns(mast,3)+ns(temp1,3)+ns(precip1,3)+temp2+ns(precip2,3)+ns(z,3)+ns(srcv,3)+sg+ns(zms,3)+bs+twi+tc2+tc1+tc3, data=yubr.df2[,5:19])
yubr.full2 <- lm(yubr.d ~ ns(mast,3)+ns(temp1,3)+precip1+ns(temp2,3)+precip2+ns(temp1,3)+precip3+ns(z,3)+sg+ns(zms,3)+znh+twi+tc2, data=yubr.df2)
library(MASS)
yubr.step <- stepAIC(yubr.full, trace=F)
library(splines)
yubr.lm <- lm(yubr.d ~ ns(temp1,3)+sg, data=yubr.df2)
termplot(yubr.lm, partial.resid=T)

# Create and export spatial model
yubr.raster <- predict(geodata, yubr.lm, index=1, progress='text')
writeRaster(yubr.raster,filename="D:/workspace/yubr.raster.tif",format="GTiff",datatype="FLT4S",overwrite=T,NAflag=-99999)

library(mgcv)
yubr.gam <- gam(yubr.d ~ s(temp1)+s(tc2)+zms+sg+s(srcv)+s(znh), data=yubr.df)
yubr2.raster <- predict(geodata, yubr.gam, progress='text')
writeRaster(yubr2.raster,filename="C:/Users/stephen.roecker/Documents/work/workspace/yubr2.raster.tif",format="GTiff",datatype="FLT4S",overwrite=T,NAflag=-99999)
