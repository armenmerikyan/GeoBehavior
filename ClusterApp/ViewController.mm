//
//  ViewController.m
//  ClusterApp
//
//  Created by Tatevik Gasparyan on 4/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#import "MyCLController.h"
#import "PlaceMark.h"
#import "SQLiteManager.h"
#import "PinView.h"
#import "CSMapRouteLayerView.h"
#import "constants.h"
#import "QuartzCore/QuartzCore.h"

#include <iostream>
//#include <vector>



//----------------------------------------------------------------------
//  Termination conditions
//      These are explained in the file KMterm.h and KMlocal.h.  Unless
//      you are into fine tuning, don't worry about changing these.
//----------------------------------------------------------------------
KMterm  term(100, 0, 0, 0,              // run for 100 stages
             0.10,                   // min consec RDL
             0.10,                   // min accum RDL
             3,                      // max run fstages
             0.50,                   // init. prob. of acceptance
             10,                     // temp. run length
             0.95);                  // temp. reduction factor

double sinc(double x)
{
    if (x == 0)
        return 1;
    return sin(x)/x;
}


void execute()
{
    // Here we declare that our samples will be 1 dimensional column vectors.  In general, 
    // you can use N dimensional vectors as inputs to the krls object.  But here we only 
    // have 1 dimension to make the example simple.  (Note that if you don't know the 
    // dimensionality of your vectors at compile time you can change the first number to 
    // a 0 and then set the size at runtime)
    // HELLO PULL REQ
    typedef dlib::matrix<double,1,1> sample_type;
    
    // Now we are making a typedef for the kind of kernel we want to use.  I picked the
    // radial basis kernel because it only has one parameter and generally gives good
    // results without much fiddling.
    typedef dlib::radial_basis_kernel<sample_type> kernel_type;
    
    // Here we declare an instance of the krls object.  The first argument to the constructor
    // is the kernel we wish to use.  The second is a parameter that determines the numerical 
    // accuracy with which the object will perform part of the regression algorithm.  Generally
    // smaller values give better results but cause the algorithm to run slower.  You just have
    // to play with it to decide what balance of speed and accuracy is right for your problem.
    // Here we have set it to 0.001.
    dlib::krls<kernel_type> test(kernel_type(0.1),0.001);
    
    // now we train our object on a few samples of the sinc function.
    sample_type m;
    for (double x = -10; x <= 4; x += 1)
    {
        m(0) = x;
        test.train(m, sinc(x));
    }
    
    // now we output the value of the sinc function for a few test points as well as the 
    // value predicted by krls object.
    m(0) = 2.5; cout << sinc(m(0)) << "   " << test(m) << endl;
    m(0) = 0.1; cout << sinc(m(0)) << "   " << test(m) << endl;
    m(0) = -4;  cout << sinc(m(0)) << "   " << test(m) << endl;
    m(0) = 5.0; cout << sinc(m(0)) << "   " << test(m) << endl;
    
    // The output is as follows:
    // 0.239389   0.239362
    // 0.998334   0.998333
    // -0.189201   -0.189201
    // -0.191785   -0.197267
    
    
    // The first column is the true value of the sinc function and the second
    // column is the output from the krls estimate.  
}

@implementation ViewController

@synthesize algorithm;
@synthesize map;
@synthesize slider;
@synthesize locationsCount, sampleCount, clusterCount, distinctCount, avgDist;
@synthesize calculateButton, historyButton, allButton;

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
        
    locationManager = [[MyCLController alloc] init];
    locationManager.delegate = self;
    [locationManager.locationManager startUpdatingLocation];
    
    //pointsDictionary = [[[NSMutableDictionary alloc] init]retain];
    //countDictionary = [[[NSMutableDictionary alloc] init]retain];

    centerPoints = [[NSMutableArray alloc] init];
    allClustersCentersArray = [[NSMutableArray alloc] init];
    visitCentersCountArray = [[NSMutableDictionary alloc] init];
    pointsCount = 1;
    clustersCount = 1;
    
    map.delegate = self;
    
    slider.minimumValue = 1.0;
    slider.maximumValue = 50.0;
    //slider.continuous = NO;
    slider.value = 1.0;
    
    sqliteManager = [[SQLiteManager alloc] initWithDatabaseNamed:@"location.db"];
    [self createLocationTable];
    nPts = 1;
    
    arrayOfLines = [[NSMutableArray alloc] init];

    useCurrentLocationAsStartCluster = YES;
    CALayer * downButtonLayer = [calculateButton layer];
    [downButtonLayer setMasksToBounds:YES];
    [downButtonLayer setCornerRadius:10.0];
    [downButtonLayer setBorderWidth:3.0];
    
    //downButtonLayer.backgroundColor = [[UIColor blueColor] CGColor];
    downButtonLayer.opacity = .5;
    downButtonLayer = [historyButton layer];
    [downButtonLayer setMasksToBounds:YES];
    [downButtonLayer setCornerRadius:10.0];
    [downButtonLayer setBorderWidth:3.0];      
    //downButtonLayer.backgroundColor = [[UIColor blueColor] CGColor];
    downButtonLayer.opacity = .5;
    
    downButtonLayer = [allButton layer];
    [downButtonLayer setMasksToBounds:YES];
    [downButtonLayer setCornerRadius:10.0];
    [downButtonLayer setBorderWidth:3.0];      
    //downButtonLayer.backgroundColor = [[UIColor blueColor] CGColor];
    downButtonLayer.opacity = .5;
}

-(IBAction) drawClusters:(id)sender
{
    if(sender != nil)
    {
        useCurrentLocationAsStartCluster = YES;
    }
    if(nPts > 0)
    {
        delete dataPts;
        delete ctrs;
        dataPts = new KMdata(dim, maxPts);            // allocate data storage
        
        [self setInputs:*dataPts];
        
        //cout << "Data Points:\n";                   // echo data points
        //for (int i = 0; i < nPts; i++)
        //    printPt(cout, (*dataPts)[i], dim);
        
        (*dataPts).setNPts(nPts);                      // set actual number of pts
        (*dataPts).buildKcTree();                      // build filtering structure
        
        ctrs = new KMfilterCenters(clustersCount, *dataPts);           // allocate centers
        
        int algorithmId = [algorithm selectedSegmentIndex];
        
        switch (algorithmId) {
            case 0:
            {
                cout << "\nExecuting Clustering Algorithm: Lloyd's\n";
                KMlocalLloyds kmLloyds(*ctrs, term);         // repeated Lloyd's
                delete ctrs;
                ctrs = new KMfilterCenters(kmLloyds.execute());                  // execute
                //printSummary(kmLloyds, *dataPts, *ctrs);      // print summary
                break;
            }
            case 1:
            {
                cout << "\nExecuting Clustering Algorithm: Swap\n";
                KMlocalSwap kmSwap(*ctrs, term);             // Swap heuristic
                delete ctrs;
                ctrs = new KMfilterCenters(kmSwap.execute());
                //printSummary(kmSwap, dataPts, ctrs);
                break;
            }
            case 2:
            {
                cout << "\nExecuting Clustering Algorithm: EZ-Hybrid\n";
                KMlocalEZ_Hybrid kmEZ_Hybrid(*ctrs, term);   // EZ-Hybrid heuristic
                delete ctrs;
                ctrs = new KMfilterCenters(kmEZ_Hybrid.execute());
                //printSummary(kmEZ_Hybrid, dataPts, ctrs);
                break;
            }
                
            default:
            {
                cout << "\nExecuting Clustering Algorithm: Hybrid\n";
                KMlocalHybrid kmHybrid(*ctrs, term);         // Hybrid heuristic
                delete ctrs;
                ctrs = new KMfilterCenters(kmHybrid.execute());
                //printSummary(kmHybrid, dataPts, ctrs);
                break;
            }
        }
        [self drawCenters:*ctrs];
    }
}

-(IBAction)setInputs:(KMdata&)data
{
    NSString* selectCommand;
    //map.visibleMapRect.size.height
    //NSLog(@"Visible Map Rect %@",MKStringFromMapRect(map.visibleMapRect));
    
    MKCoordinateRegion rect = map.region;
    NSLog(@"RECT %f %f %f %f", rect.center.latitude, rect.center.longitude, rect.span.latitudeDelta, rect.span.longitudeDelta);
    
    if(isQueryAll){
        selectCommand = [NSString stringWithFormat:@"SELECT * from %@", LOCATIONS_TABLE];
    }else {
        selectCommand = [NSString stringWithFormat:@"SELECT * from %@ where latitude between %f and %f and longitude between %f and %f", LOCATIONS_TABLE, rect.center.latitude - rect.span.latitudeDelta, rect.center.latitude + rect.span.latitudeDelta, rect.center.longitude - rect.span.longitudeDelta, rect.center.longitude + rect.span.longitudeDelta];
    }    
    NSArray* resultArray = [sqliteManager getRowsForQuery:selectCommand];
    nPts = [resultArray count];
    NSLog(@"select command %@ %d", selectCommand, nPts);
    for(int i = 0; i < [resultArray count]; ++i)
    {
        data[i][0] = [[[resultArray objectAtIndex:i] objectForKey:@"latitude"] floatValue];//currentLocation.coordinate.latitude;
        data[i][1] = [[[resultArray objectAtIndex:i] objectForKey:@"longitude"] floatValue];//currentLocation.coordinate.longitude;
        
        //CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(data[i][0], data[i][1]);
        //MKCircle *circle = [MKCircle circleWithCenterCoordinate:coord radius:5];
        //[map addOverlay:circle];
        
        //NSLog(@"coordinate %f %f %@ %@", data[i][0], data[i][1], [[resultArray objectAtIndex:i] objectForKey:@"latitude"], [[resultArray objectAtIndex:i] objectForKey:@"longitude"]);
    }
    locationsCount.text = [NSString stringWithFormat:@"Total : %d", nPts];
}

-(IBAction) drawCenters:(KMfilterCenters&)centers
{
    //Remove previous annotations
    [map removeAnnotations:map.annotations];
    
    KMdistArray distArray = centers.getDists(); 
    
    NSMutableDictionary* dictionary = [[NSMutableDictionary alloc] init];
    NSUInteger clusterId = changedClusterId;
    CGPoint centerPoint = defaultPoint;
    if(useCurrentLocationAsStartCluster == NO)
    {
        NSArray* uniqueCentersArray = centerPoints;//[self getUniqueCenters:*ctrs];
        changedClusterId = [uniqueCentersArray indexOfObject:[NSValue valueWithCGPoint:selectedPoint]];
        NSLog(@"CLuster center %@", NSStringFromCGPoint([[uniqueCentersArray objectAtIndex:clusterId] CGPointValue]));
        centerPoint = selectedPoint;
    }
    [self getProbabilities:centerPoint :dictionary];
    
    int centersCount = centers.getK();
    NSArray* uniqueCentersArray = centerPoints;
    centersCount = [uniqueCentersArray count];
    
    for (int i = 0; i < centersCount; ++i)
    {
        CGPoint point = [[uniqueCentersArray objectAtIndex:i] CGPointValue];
        int index = [uniqueCentersArray indexOfObject:[NSValue valueWithCGPoint:centerPoint]];
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(point.x, point.y);
        
        NSString* probabilityString;
        if(index == i)
        {
            probabilityString = @"Current Item";
        }
        else
        {
            //float currentClusterVisitCount = [[locationsProbability objectForKey:[keyArray objectAtIndex:i]] intValue];
            
            probabilityString = [NSString stringWithFormat:@"Probability %.2f%%",[[dictionary objectForKey:[NSValue valueWithCGPoint:point]] floatValue] * 100];
        }
        PlaceMark* placeMark = [[PlaceMark alloc] initWithCoordinate:coord title:probabilityString subtitle:[NSString stringWithFormat:@"Distortion : %f", distArray[i]]];
        placeMark.probability = [[dictionary objectForKey:[NSValue valueWithCGPoint:point]] floatValue] * 100;
        placeMark.clusterId = i;
        [map addAnnotation:placeMark];
        [placeMark release];
        /*
        if(index != i && [[dictionary objectForKey:[NSValue valueWithCGPoint:point]] floatValue] > 0.0)
        {
            [self drawLine:point :centerPoint];
        }
         */
    }
    avgDist.text = [NSString stringWithFormat:@"Distortion : %f",  centers.getAvgDist()];
    [dictionary release];
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    
    //[self removeAllLines];
    
    NSLog(@"CHANGE zoom %f %f", mapView.region.span.latitudeDelta, mapView.region.span.longitudeDelta);
    //zoom level 0 then clusters count 1000
    //zoom level 150 then clusters count 10
    //equation -4.95x + 1000
    //clustersCount = -4.95 * mapView.region.span.longitudeDelta + 1000;
    NSUInteger zoomLevel = 20;
    MKZoomScale zoomScale = mapView.bounds.size.width / mapView.visibleMapRect.size.width;
    double zoomExponent = log2(zoomScale);
    zoomLevel = (NSUInteger)(20 - ceil(zoomExponent));
    //if(zoomLevel >30){
    //    clustersCount = 100;    
    //}else {
    //    clustersCount = 1000;
    //}
    NSLog(@"CLUSTERS COUNT %d", clustersCount);
    NSLog(@"ZOOM LEVEL %d", zoomLevel);
    
    for(int i = 0; i < [arrayOfLines count]; ++i)
    {
        CSMapRouteLayerView* route = [arrayOfLines objectAtIndex:i];
        [route setNeedsDisplay];
    }
    
}

//Delegate methods

- (void)locationUpdate:(CLLocation *)location
{
    if(updateCount == 5){
    //Do actions when the GPS is Updating
    //NSLog(@"Upedated location %.4f %.4f", location.coordinate.latitude, location.coordinate.longitude);
    //[location retain];
    float latitude = location.coordinate.latitude;
    float longitude = location.coordinate.longitude;

    NSDate *currentDate = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        
    NSString *dateString = [formatter stringFromDate:currentDate];
    [formatter release];
    
    NSString* insertCommand = [NSString stringWithFormat:@"INSERT INTO %@ VALUES(\"%.4f\", \"%.4f\", \"%@\")", LOCATIONS_TABLE, latitude, longitude, dateString];
    //NSLog(@"command %@", insertCommand);
    NSError* error = [sqliteManager doQuery:insertCommand];
    if(nil != error)
    {
        UIAlertView* errorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:error.description delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [errorAlert show];
        [errorAlert release];
    }
    
    /*if(++pointsCount % 10 == 0)
    {
        //[self drawClusters];
    } */   
        sampleCount.textColor = [UIColor redColor];
        sampleCount.text = [NSString stringWithFormat:@"Recording"];
        updateCount = 0;
    //locationsCount.text = [NSString stringWithFormat:@"%d", [pointsDictionary count]];
    }else {
        sampleCount.textColor = [UIColor blackColor];
        sampleCount.text = [NSString stringWithFormat:@"Waiting %d of 5", updateCount +1];
        updateCount += 1;
        
    }
    
}
- (void)locationError:(NSError *)error
{
    NSString* errorDescription = (1 != error.code)? error.description : @"The current location is not available";
    UIAlertView* errorAlertView = [[UIAlertView alloc] initWithTitle:@"Error" message:errorDescription delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
    [errorAlertView show];
    [errorAlertView release];
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    //return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    return NO;
}

-(void)dealloc
{
    [locationManager release];
    [algorithm release];
    [map release];
    [sqliteManager release];
    [slider release];
    [locationsCount release];
    [sampleCount release];
    [clusterCount release];
    [avgDist release];
    [distinctCount release];
    [centerPoints release];
    
    delete ctrs;
    delete dataPts;
    
    [super dealloc];
}
-(IBAction) drawLayersAll:(id)sender {
    //[self removeAllLines];
    isQueryAll = true;
    [self drawClusters:sender];
}
-(IBAction) drawLayers:(id)sender {
    //[self removeAllLines];
    isQueryAll = false;
    [self drawClusters:sender];
}
-(IBAction) drawDistinctLocations:(id)sender{
    [map removeOverlays:map.overlays];
    if(isShowingDetail){
        isShowingDetail = false;
        [historyButton setTitle:@"Show" forState:UIControlStateNormal];
        [historyButton setTitle:@"Show" forState:UIControlStateHighlighted];
        [historyButton setTitle:@"Show" forState:UIControlStateDisabled];
        [historyButton setTitle:@"Show" forState:UIControlStateSelected];        
        return ;
    }
    isShowingDetail = true;
    [historyButton setTitle:@"Hide" forState:UIControlStateNormal];
    [historyButton setTitle:@"Hide" forState:UIControlStateHighlighted];
    [historyButton setTitle:@"Hide" forState:UIControlStateDisabled];
    [historyButton setTitle:@"Hide" forState:UIControlStateSelected];    
    
    NSString* selectCommand = [NSString stringWithFormat:@"SELECT Distinct latitude, longitude from %@", LOCATIONS_TABLE];
    NSArray* resultArray = [sqliteManager getRowsForQuery:selectCommand];
    nPts = [resultArray count];
    for(int i = 0; i < [resultArray count]; ++i)
    {
        //data[i][0] = ;//currentLocation.coordinate.latitude;
        //data[i][1] = ;//currentLocation.coordinate.longitude;
        
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([[[resultArray objectAtIndex:i] objectForKey:@"latitude"] floatValue], [[[resultArray objectAtIndex:i] objectForKey:@"longitude"] floatValue]);
        MKCircle *circle = [MKCircle circleWithCenterCoordinate:coord radius:5];
        [map addOverlay:circle];
    }
    distinctCount.text = [NSString stringWithFormat:@"Unique : %d", [resultArray count]];
}
-(IBAction) sliderChanged:(id)sender {
    /*if(pointsCount<slider.value){
        slider.value = pointsCount;
    }*/
    /*if ([pointsDictionary count]<slider.value) {
        slider.value = [pointsDictionary count];
    }*/
    if(nPts ==1){
        UIAlertView* completeAlert = [[UIAlertView alloc] initWithTitle:@"Note" message:@"You must Calculate once before you increasing location centers." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[completeAlert show];
		[completeAlert release];
        
    }
    
    else if (nPts<slider.value) {
        slider.value = nPts;
        UIAlertView* completeAlert = [[UIAlertView alloc] initWithTitle:@"Note" message:@"Location centers can't be greater than total locations saved. Please wait for the application to save more locations and calculate" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[completeAlert show];
		[completeAlert release];
    }
    slider = (UISlider *)sender;
    int progressAsInt = (int)(slider.value + 0.5f);
    NSLog(@"Slider Value: %d", progressAsInt); 
    clustersCount = progressAsInt;
    clusterCount.text = [NSString stringWithFormat:@"%d", clustersCount];
    
}
-(MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay{
	if([overlay isKindOfClass:[MKPolygon class]]){
		MKPolygonView *view = [[MKPolygonView alloc] initWithOverlay:overlay];
		view.lineWidth=1;
		view.strokeColor=[UIColor blueColor];
		view.fillColor=[[UIColor blueColor] colorWithAlphaComponent:0.1];
		return [view autorelease];
	}
	if([overlay isKindOfClass:[MKCircle class]]){
		MKCircleView *view = [[MKCircleView alloc] initWithOverlay:overlay];
		view.lineWidth=1;
		view.strokeColor=[UIColor blueColor];
		view.fillColor=[[UIColor blueColor] colorWithAlphaComponent:0.1];
        
		return [view autorelease];
	}    
	return nil;
}
-(IBAction)createLocationTable
{
    NSString* tableCreateCommand = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (latitude FLOAT, longitude FLOAT, date TEXT )", LOCATIONS_TABLE];
    NSError* error = [sqliteManager doQuery:tableCreateCommand];
    if(nil != error)
    {
        UIAlertView* errorAlert = [[UIAlertView alloc] initWithTitle:@"Error" message:error.description delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [errorAlert show];
        [errorAlert release];
    }
}

/*-(NSArray*)getUniqueCenters:(KMfilterCenters)centers
{
    points = centers.getCtrPts();
    int centersCount = centers.getK();
    
    NSMutableArray* uniqueCentersMutableArray = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < centersCount; ++i)
    {
        CGPoint point = CGPointMake(points[i][0], points[i][1]);
        NSValue* pointValue = [NSValue valueWithCGPoint:point];
        if( NSNotFound == [uniqueCentersMutableArray indexOfObject:pointValue])
        {
            [uniqueCentersMutableArray addObject:pointValue];
        }
    }
    NSArray* uniqieCentersArray = [NSArray arrayWithArray:uniqueCentersMutableArray];
    [uniqueCentersMutableArray release];
    return uniqieCentersArray;

}*/

-(NSArray*)getAllCentersArrayFromLocations
{
    KMpointArray points = ctrs->getCtrPts();
    int centersCount = ctrs->getK();

    for(int i = 0; i < centersCount; ++i)
    {
        NSLog(@"POINTS %.4f %.4f", points[i][0], points[i][1]);
    }
    
    NSMutableArray* uniqueCentersMutableArray = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < centersCount; ++i)
    {
        CGPoint point = CGPointMake(points[i][0], points[i][1]);
        NSValue* pointValue = [NSValue valueWithCGPoint:point];
        if( NSNotFound == [uniqueCentersMutableArray indexOfObject:pointValue])
        {
            [uniqueCentersMutableArray addObject:pointValue];
        }
    }

    centerPoints = [uniqueCentersMutableArray mutableCopy];
    [uniqueCentersMutableArray release];
    
    
    NSMutableArray* resultArray = [[NSMutableArray alloc] init];
    //points = (*ctrs).getCtrPts();
    
    KMctrIdxArray closeCtr = new KMctrIdx[(*dataPts).getNPts()];
    double* sqDist = new double[(*dataPts).getNPts()];
    (*ctrs).getAssignments(closeCtr, sqDist);
    
    *kmOut      << "(Cluster assignments:\n"
    << "    Point  Center  Squared Dist\n"
    << "    -----  ------  ------------\n";
    
    NSString* firstString = NSStringFromCGPoint(CGPointMake(points[closeCtr[0]][0], points[closeCtr[0]][1]));
    
    for (int i = 0; i < (*dataPts).getNPts(); i++) 
    {
        CGPoint point = CGPointMake(points[closeCtr[i]][0], points[closeCtr[i]][1]);
        if(![firstString isEqualToString:NSStringFromCGPoint(point)])
        {
            firstString = NSStringFromCGPoint(point);
        }
        if([resultArray count] == 0 || ![self comparePoints:[[resultArray lastObject] CGPointValue] :point])
        {
            [resultArray addObject:[NSValue valueWithCGPoint:point]];
            defaultPoint = point;
        }
    }
    delete [] closeCtr;
    delete [] sqDist;
    NSArray* array = [NSArray arrayWithArray:resultArray];
    [resultArray release];
    return array;
}

-(IBAction)calculateProbabilities:(CGPoint)centerPoint :(NSMutableDictionary*)locationsProbability
{
    for(int i = 0; i < [centerPoints count]; ++i)
    {
        CGPoint currentPoint = [[centerPoints objectAtIndex:i] CGPointValue];
        if([self comparePoints:currentPoint :centerPoint])
        {
            continue;
        }
        
        [locationsProbability setObject:[NSNumber numberWithInt:0] forKey:[NSValue valueWithCGPoint:currentPoint]];
        
        NSMutableArray* arrayForIteration = [allClustersCentersArray mutableCopy];
        
        int startIndex = [arrayForIteration indexOfObject:[NSValue valueWithCGPoint:centerPoint]];
        while(startIndex < [arrayForIteration count] -1)
        {
            if([self comparePoints:[[arrayForIteration objectAtIndex:startIndex + 1] CGPointValue] :currentPoint])
            {
                int count = [[locationsProbability objectForKey:[NSValue valueWithCGPoint:currentPoint]] intValue];
                [locationsProbability setObject:[NSNumber numberWithInt:count + 1] forKey:[NSValue valueWithCGPoint:currentPoint]];
                
            }
            [arrayForIteration removeObjectAtIndex:startIndex];
            startIndex = [arrayForIteration indexOfObject:[NSValue valueWithCGPoint:centerPoint]];
        }
        [arrayForIteration release];
    }
    
    float overalCount = 0.0;
    NSEnumerator *enumerator = [locationsProbability keyEnumerator];
    id key;
    while ((key = [enumerator nextObject])) 
    {
        overalCount += [[locationsProbability objectForKey:key] intValue];
    }
    
    NSArray *keyArray =  [locationsProbability allKeys];
    int count = [keyArray count];
    for (int i = 0; i < count; ++i)
    {
        float currentClusterVisitCount = [[locationsProbability objectForKey:[keyArray objectAtIndex:i]] intValue];
        NSNumber *probability = (overalCount == 0)? [NSNumber numberWithFloat:1.0 / count] : [NSNumber numberWithFloat:currentClusterVisitCount / overalCount];
        [locationsProbability setObject:probability forKey:[keyArray objectAtIndex:i]];
        NSLog(@"Probability %f %f %f",overalCount, currentClusterVisitCount, currentClusterVisitCount / overalCount);
    }
    
    //Remove previous annotations
    [map removeAnnotations:map.annotations];
    
    
    if(useCurrentLocationAsStartCluster == NO)
    {
        NSArray* uniqueCentersArray = centerPoints;//[self getUniqueCenters:*ctrs];
        changedClusterId = [uniqueCentersArray indexOfObject:[NSValue valueWithCGPoint:selectedPoint]];
        centerPoint = selectedPoint;
    }
    
    NSArray* uniqueCentersArray = centerPoints;//[self getUniqueCenters:centers];
    
    int centersCount = [uniqueCentersArray count];
    
    for (int i = 0; i < centersCount; ++i)
    {
        CGPoint point = [[uniqueCentersArray objectAtIndex:i] CGPointValue];
        int index = [uniqueCentersArray indexOfObject:[NSValue valueWithCGPoint:centerPoint]];
        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(point.x, point.y);
        
        NSString* probabilityString;
        if(index == i)
        {
            probabilityString = @"Current Item";
        }
        else
        {
            probabilityString = [NSString stringWithFormat:@"Probability %.2f%%",[[locationsProbability objectForKey:[NSValue valueWithCGPoint:point]] floatValue] * 100];
        }
        KMdistArray distArray = ctrs->getDists(); 
        PlaceMark* placeMark = [[PlaceMark alloc] initWithCoordinate:coord title:probabilityString subtitle:[NSString stringWithFormat:@"Distortion : %f", distArray[i]]];
        placeMark.probability = [[locationsProbability objectForKey:[NSValue valueWithCGPoint:point]] floatValue] * 100;
        placeMark.clusterId = i;
        [map addAnnotation:placeMark];
        [placeMark release];
        //[map setCenterCoordinate:coord];
        /*
        if(index != i && [[locationsProbability objectForKey:[NSValue valueWithCGPoint:point]] floatValue] > 0.0)
        {
            [self drawLine:point :centerPoint];
        }
         */
    }
    avgDist.text = [NSString stringWithFormat:@"Distortion : %f",  ctrs->getAvgDist()];
    [locationsProbability release];
}

-(IBAction) getProbabilities:(CGPoint)centerPoint :(NSMutableDictionary*)locationsProbability
{    
    NSArray* array = [self getAllCentersArrayFromLocations];
    [allClustersCentersArray release];
    allClustersCentersArray = [array mutableCopy];
    NSArray* uniqueLocations = centerPoints;

    defaultPoint = [[array lastObject] CGPointValue];
    centerPoint = defaultPoint;
    NSLog(@"Center  %.4f %.4f", centerPoint.x, centerPoint.y);
    for(int i = 0; i < [uniqueLocations count]; ++i)
    {
        CGPoint currentPoint = [[uniqueLocations objectAtIndex:i] CGPointValue];
        if([self comparePoints:currentPoint :centerPoint])//if(CGPointEqualToPoint(currentPoint, centerPoint))//if(index == i)
        {
            continue;
        }
        
        [locationsProbability setObject:[NSNumber numberWithInt:0] forKey:[NSValue valueWithCGPoint:currentPoint]];
        
        NSMutableArray* arrayForIteration = [array mutableCopy];

        int startIndex = [arrayForIteration indexOfObject:[NSValue valueWithCGPoint:centerPoint]];
        while(startIndex < [arrayForIteration count] -1)
        {
            if([self comparePoints:[[arrayForIteration objectAtIndex:startIndex + 1] CGPointValue] :currentPoint])
            {
                int count = [[locationsProbability objectForKey:[NSValue valueWithCGPoint:currentPoint]] intValue];
                [locationsProbability setObject:[NSNumber numberWithInt:count + 1] forKey:[NSValue valueWithCGPoint:currentPoint]];

            }
            [arrayForIteration removeObjectAtIndex:startIndex];
            startIndex = [arrayForIteration indexOfObject:[NSValue valueWithCGPoint:centerPoint]];
        }
        [arrayForIteration release];
    }
    
    float overalCount = 0.0;
    NSEnumerator *enumerator = [locationsProbability keyEnumerator];
    id key;
    while ((key = [enumerator nextObject])) 
    {
        overalCount += [[locationsProbability objectForKey:key] intValue];
    }
    
    NSArray *keyArray =  [locationsProbability allKeys];
    int count = [keyArray count];
    for (int i = 0; i < count; ++i)
    {
        float currentClusterVisitCount = [[locationsProbability objectForKey:[keyArray objectAtIndex:i]] intValue];
        NSNumber *probability = (overalCount == 0)? [NSNumber numberWithFloat:1.0 / count] : [NSNumber numberWithFloat:currentClusterVisitCount / overalCount];
        [locationsProbability setObject:probability forKey:[keyArray objectAtIndex:i]];
        NSLog(@"Probability %f %f %f",overalCount, currentClusterVisitCount, currentClusterVisitCount / overalCount);
    }
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{	
	// if it's the user location, just return nil.
    if ([annotation isKindOfClass:[MKUserLocation class]])
        return nil;
    
	// try to dequeue an existing pin view first
	static NSString* AnnotationIdentifier = @"AnnotationIdentifier";
	PinView* pinView = [[[PinView alloc]
                           initWithAnnotation:annotation reuseIdentifier:AnnotationIdentifier] autorelease];
	//pinView.animatesDrop=YES;
	pinView.canShowCallout=YES;
	//pinView.pinColor=MKPinAnnotationColorPurple;
    PlaceMark* pin = (PlaceMark*)annotation;
	
	UIButton* rightButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
	[rightButton setTitle:annotation.title forState:UIControlStateNormal];
	[rightButton addTarget:self
					action:@selector(changeCurrentCluster)
		  forControlEvents:UIControlEventTouchUpInside];
	pinView.rightCalloutAccessoryView = rightButton;
    CGPoint point = CGPointMake(pin.coordinate.latitude, pin.coordinate.longitude);
    //if((useCurrentLocationAsStartCluster && pin.clusterId == selectedPin) || (!useCurrentLocationAsStartCluster && pin.clusterId == changedClusterId))
    NSLog(@"PIN Probability %f", pin.probability);
    if((useCurrentLocationAsStartCluster && [self comparePoints:point :defaultPoint]) || (!useCurrentLocationAsStartCluster && [self comparePoints:point :selectedPoint]))
    {
        pinView.image = [UIImage imageNamed:@"green_pin.png"];
        //pinView.pinColor = MKPinAnnotationColorGreen;
    }
    else if(pin.probability  == 0.0)
    {
        //pinView.pinColor = MKPinAnnotationColorRed;
        pinView.image = [UIImage imageNamed:@"red_pin.png"];
        
    }
    else if(pin.probability < 30.0)
    {
        pinView.image = [self getImageWithLabel:pin.probability imageNamed:@"orange_pin.png"];
        //pinView.pinColor = MKPinAnnotationColorPurple;
    }
    else
    {
        pinView.image = [self getImageWithLabel:pin.probability imageNamed:@"map_pin.png"];
    }
	
	return pinView;
}


-(UIImage*) getImageWithLabel:(int)digit imageNamed:(NSString *)name
{
    UIImage *myImage = [UIImage imageNamed:name];
    NSString *myWatermarkText = [NSString stringWithFormat:@"%d%%", digit];
    UIImage *watermarkedImage = nil;
    
    UIGraphicsBeginImageContext(myImage.size);
    [myImage drawAtPoint: CGPointZero];
    if (digit >99.99) {
        myWatermarkText = @"100";
        [myWatermarkText drawAtPoint: CGPointMake(5, 25) withFont: [UIFont systemFontOfSize: 13]];    
    }
    else if (digit >9) {
        [myWatermarkText drawAtPoint: CGPointMake(5, 25) withFont: [UIFont systemFontOfSize: 13]];
    }else{
        [myWatermarkText drawAtPoint: CGPointMake(8, 25) withFont: [UIFont systemFontOfSize: 13]];    
    }
    watermarkedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return watermarkedImage;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    //This will call viewForAnnotation again
    
    PinView* pinView = (PinView*)view;
    PlaceMark* mark = (PlaceMark*)pinView.annotation;
    NSLog(@"CLICKED !!! %d", mark.clusterId);
    lastTouchedPin = mark.clusterId;
    selectedPoint = CGPointMake(mark.coordinate.latitude, mark.coordinate.longitude);
}

-(IBAction)changeCurrentCluster
{
    useCurrentLocationAsStartCluster = NO;
    changedClusterId = lastTouchedPin;
    
    NSMutableDictionary* dictionary = [[NSMutableDictionary alloc] init];
    visitCentersCountArray = [[NSMutableDictionary alloc] init];
    /*
    [self removeAllLines];
     */
    [self calculateProbabilities:selectedPoint :dictionary];
     
}

-(BOOL)comparePoints:(CGPoint)p1 :(CGPoint)p2
{
    NSString* str1 = [NSString stringWithFormat:@"%.4f%.4f", p1.x, p1.y];
    NSString* str2 = [NSString stringWithFormat:@"%.4f%.4f", p2.x, p2.y];
    return [str1 isEqualToString:str2];
}

-(IBAction)drawLine:(CGPoint)points1 :(CGPoint)points2
{
    CLLocation* startLocation = [[CLLocation alloc] initWithLatitude:points1.x longitude:points1.y];
    CLLocation* endLocation = [[CLLocation alloc] initWithLatitude:points2.x longitude:points2.y];
    NSArray* pointsArray = [NSArray arrayWithObjects:startLocation, endLocation, nil];
    CSMapRouteLayerView* routeView = [[CSMapRouteLayerView alloc] initWithRoute:pointsArray mapView:map];
	[routeView setNeedsDisplay];
    [arrayOfLines addObject:routeView];
}

-(IBAction)removeAllLines
{
    for(int i = 0; i < [arrayOfLines count]; ++i)
    {
        CSMapRouteLayerView* line = [arrayOfLines objectAtIndex:i];
        [line removeFromSuperview];
        [line release];
    }
    [arrayOfLines removeAllObjects];
}

-(IBAction)runAlgorithm
{
    execute();
}

@end
