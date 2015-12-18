//
//  CodeGenTestTests.m
//  CodeGenTestTests
//
//  Copyright (c) 2015 StrongLoop. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "XXWidget.h"
#import "XXWidgetRepository.h"


// Utility macros for asynchronous testing
// NOTE: since the CI uses Xcode 5, we cannot depend on XCTestExpectation.
// Use dispatch_semaphore instead.
#define ASYNC_TEST_START dispatch_semaphore_t sen_semaphore = dispatch_semaphore_create(0);
#define ASYNC_TEST_END \
while (dispatch_semaphore_wait(sen_semaphore, DISPATCH_TIME_NOW)) \
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
#define ASYNC_TEST_SIGNAL dispatch_semaphore_signal(sen_semaphore);
#define ASYNC_TEST_FAILURE_BLOCK \
    ^(NSError *error) { \
        XCTFail(@"Test failed: %@", error.description); \
        ASYNC_TEST_SIGNAL \
    }


@interface CodeGenTestTests : XCTestCase

@property (nonatomic, strong) LBRESTAdapter *adapter;
@property (nonatomic, strong) XXWidgetRepository *repository;

@end


static NSNumber *createdId;


@implementation CodeGenTestTests

/**
 * Create the default test suite to control the order of test methods
 */
+ (id)defaultTestSuite {
    XCTestSuite *suite = [XCTestSuite testSuiteWithName:@"TestSuite for LBFile."];
    [suite addTest:[self testCaseWithSelector:@selector(testSave)]];
    [suite addTest:[self testCaseWithSelector:@selector(testExists)]];
    [suite addTest:[self testCaseWithSelector:@selector(testFindById)]];
    [suite addTest:[self testCaseWithSelector:@selector(testFindByIdFilter)]];
    [suite addTest:[self testCaseWithSelector:@selector(testAll)]];
    [suite addTest:[self testCaseWithSelector:@selector(testFindWithFilter)]];
    [suite addTest:[self testCaseWithSelector:@selector(testFindOne)]];
    [suite addTest:[self testCaseWithSelector:@selector(testFindOneWithFilter)]];
    [suite addTest:[self testCaseWithSelector:@selector(testUpdate)]];
    [suite addTest:[self testCaseWithSelector:@selector(testUpdateAllWithWhereFilterData)]];
    [suite addTest:[self testCaseWithSelector:@selector(testCount)]];
    [suite addTest:[self testCaseWithSelector:@selector(testCountWithWhereFilter)]];
    [suite addTest:[self testCaseWithSelector:@selector(testDataTypes)]];
    [suite addTest:[self testCaseWithSelector:@selector(testRemove)]];
    return suite;
}

- (void)setUp {
    [super setUp];

    self.adapter = [LBRESTAdapter adapterWithURL:[NSURL URLWithString:@"http://localhost:3010/api"]];
    self.repository = (XXWidgetRepository*)[self.adapter repositoryWithClass:[XXWidgetRepository class]];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testSave {
    XXWidget *widget = [self.repository modelWithDictionary:nil];
    widget.name = @"Foobar";

    ASYNC_TEST_START
    [widget saveWithSuccess:^{
        NSLog(@"Completed with: %@", widget._id);
        XCTAssertNotNil(widget._id, @"Invalid id");
        createdId = widget._id;
        ASYNC_TEST_SIGNAL
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testExists {
    ASYNC_TEST_START
    [self.repository existsWithId:createdId success:^(BOOL exists) {
        XCTAssertTrue(exists, @"No model found");
        ASYNC_TEST_SIGNAL
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testFindById {
    ASYNC_TEST_START
    [self.repository findById:createdId success:^(XXWidget *widget) {
        XCTAssertNotNil(widget, @"No model found");
        XCTAssertEqualObjects(widget.name, @"Foobar", @"Invalid name");
        ASYNC_TEST_SIGNAL
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testFindByIdFilter {
    ASYNC_TEST_START
    [self.repository findById:createdId
                       filter: @{@"where": @{ @"name" : @"Foobar" }}
                      success:^(XXWidget *widget) {
        XCTAssertNotNil(widget, @"No model found");
        XCTAssertEqualObjects(widget.name, @"Foobar", @"Invalid name");
        ASYNC_TEST_SIGNAL
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testAll {
    // Add one more widget for testing
    XXWidget *anotherWidget = [self.repository modelWithDictionary:nil];
    anotherWidget.name = @"Barfoo";

    ASYNC_TEST_START
    [anotherWidget saveWithSuccess:^{
        [self.repository allWithSuccess:^(NSArray *widgets) {
            BOOL foundWidgetFoobar = NO;
            BOOL foundWidgetBarfoo = NO;
            XCTAssertNotNil(widgets, @"No models returned.");
            XCTAssertTrue([widgets count] >= 2, @"Invalid # of models returned: %lu", (unsigned long)[widgets count]);
            for (int i = 0; i < widgets.count; i++) {
                XCTAssertTrue([[widgets[i] class] isSubclassOfClass:[XXWidget class]], @"Invalid class.");
                XXWidget *widget = widgets[i];
                if ([widget.name isEqualToString:@"Foobar"]) {
                    foundWidgetFoobar = YES;
                }
                if ([widget.name isEqualToString:@"Barfoo"]) {
                    foundWidgetBarfoo = YES;
                }
            }
            XCTAssertTrue(foundWidgetFoobar, @"Widget \"Foobar\" is not found correctly");
            XCTAssertTrue(foundWidgetBarfoo, @"Widget \"Barfoo\" is not found correctly");
            ASYNC_TEST_SIGNAL
        } failure:ASYNC_TEST_FAILURE_BLOCK];
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testFindWithFilter {
    ASYNC_TEST_START
    [self.repository findWithFilter:@{@"where": @{ @"name": @"Foobar" }}
                            success:^(NSArray *widgets) {
        XCTAssertNotNil(widgets, @"No models returned.");
        XCTAssertTrue([widgets count] >= 1, @"Invalid # of models returned: %lu", (unsigned long)[widgets count]);
        for (int i = 0; i < widgets.count; i++) {
            XCTAssertTrue([[widgets[i] class] isSubclassOfClass:[XXWidget class]], @"Invalid class.");
            XXWidget *widget = widgets[i];
            XCTAssertEqualObjects(widget.name, @"Foobar", @"Invalid name");
        }
        ASYNC_TEST_SIGNAL
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testFindOne {
    ASYNC_TEST_START
    [self.repository findOneWithSuccess:^(XXWidget *widget) {
        // There should be at least one widget
        XCTAssertNotNil(widget, @"No model found");
        ASYNC_TEST_SIGNAL
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testFindOneWithFilter {
    ASYNC_TEST_START
    [self.repository findOneWithFilter:@{@"where": @{ @"name": @"Foobar" }} success:^(XXWidget *widget) {
        XCTAssertNotNil(widget, @"No model found");
        XCTAssertEqualObjects(widget.name, @"Foobar", @"Invalid name");
        ASYNC_TEST_SIGNAL
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testUpdate {
    ASYNC_TEST_START
    [self.repository findById:createdId success:^(XXWidget *widget) {
        XCTAssertNotNil(widget, @"No model found with ID %@", createdId);
        widget.name = @"FoobarUpdated";

        [widget saveWithSuccess:^() {
            [self.repository findById:createdId success:^(XXWidget *widgetAlt) {
                XCTAssertNotNil(widgetAlt, @"No model found with ID %@", createdId);
                XCTAssertEqualObjects(widget.name, @"FoobarUpdated", @"Invalid name");
                ASYNC_TEST_SIGNAL
            } failure:ASYNC_TEST_FAILURE_BLOCK];
        } failure:ASYNC_TEST_FAILURE_BLOCK];
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testUpdateAllWithWhereFilterData {
    // Revert the change done in testUpdate
    XXWidget *widgetOrig = [self.repository modelWithDictionary:nil];
    widgetOrig.name = @"Foobar";

    ASYNC_TEST_START
    [self.repository updateAllWithWhereFilter:@{ @"name": @"FoobarUpdated" }
                                         data:widgetOrig
                                      success:^(NSDictionary *dictionary) {
        XCTAssertTrue(dictionary.count > 0, @"No model updated");
        [self.repository findById:createdId success:^(XXWidget *widget) {
            XCTAssertNotNil(widget, @"No model found");
            XCTAssertEqualObjects(widget.name, @"Foobar", @"Invalid title");
            ASYNC_TEST_SIGNAL
        } failure:ASYNC_TEST_FAILURE_BLOCK];
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testCount {
    ASYNC_TEST_START
    [self.repository countWithSuccess:^(NSInteger count) {
        NSInteger prevCount = count;

        // Add one more widget for testing
        XXWidget *anotherWidget = [self.repository modelWithDictionary:nil];
        anotherWidget.name = @"widgetForCountTest";

        [anotherWidget saveWithSuccess:^{
            [self.repository countWithSuccess:^(NSInteger count) {
                XCTAssertTrue(count == prevCount + 1, @"Invalid # of models returned: %lu", count);
                ASYNC_TEST_SIGNAL
            } failure:ASYNC_TEST_FAILURE_BLOCK];
        } failure:ASYNC_TEST_FAILURE_BLOCK];
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testCountWithWhereFilter {
    ASYNC_TEST_START
    [self.repository countWithWhereFilter:@{ @"name": @"widgetForCountTest" }
                                  success:^(NSInteger count) {
        NSInteger prevCount = count;

        // Add one more widget for testing
        XXWidget *anotherWidget = [self.repository modelWithDictionary:nil];
        anotherWidget.name = @"widgetForCountTest";

        [anotherWidget saveWithSuccess:^{
            [self.repository countWithWhereFilter:@{ @"name": @"widgetForCountTest" }
                                          success:^(NSInteger count) {
                XCTAssertTrue(count == prevCount + 1, @"Invalid # of models returned: %lu", count);
                ASYNC_TEST_SIGNAL
            } failure:ASYNC_TEST_FAILURE_BLOCK];
        } failure:ASYNC_TEST_FAILURE_BLOCK];
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testDataTypes {
    XXWidget *widget = (XXWidget*)[self.repository modelWithDictionary:@{
        @"name" : @"Foobar",
        @"bars" : @123,
        @"flag" : @YES,
        @"data" : @{ @"data1": @1, @"data2": @2 },
        @"stringArray": @[ @"one", @"two", @"three" ],
        @"date" : @"1970-01-01T00:00:00.000Z",
        @"buffer": @{ @"type": @"Buffer", @"data": @[ @12, @34, @56 ] },
        @"geopoint": @{ @"lat": @12.3, @"lng": @45.6 },
    }];

    XCTAssertNil(widget._id, @"Invalid id");
    XCTAssertEqualObjects(widget.name, @"Foobar", @"Invalid name.");
    XCTAssertEqual(widget.bars, 123, @"Invalid bars.");
    XCTAssertEqual(widget.flag, YES, @"Invalid flag.");
    XCTAssertEqualObjects(widget.data, (@{@"data1": @1, @"data2": @2}), @"Invalid data.");
    XCTAssertEqualObjects(widget.stringArray, (@[@"one", @"two", @"three"]), @"Invalid stringArray.");
    XCTAssertEqualObjects(widget.date, [NSDate dateWithTimeIntervalSince1970:0], @"Invalid date.");
    const char bufferBytes[] = { 12, 34, 56 };
    NSMutableData *testData = [NSMutableData dataWithBytes:bufferBytes length:sizeof(bufferBytes)];
    XCTAssertEqualObjects(widget.buffer, testData, @"Invalid buffer.");
    XCTAssertEqual(widget.geopoint.coordinate.latitude, 12.3, @"Invalid latitude.");
    XCTAssertEqual(widget.geopoint.coordinate.longitude, 45.6, @"Invalid longitude.");

    widget.name = @"Barfoo";
    widget.bars = 456;
    widget.flag = NO;
    widget.data = @{ @"data3": @3, @"data4": @4 };
    widget.stringArray = @[ @"four", @"five", @"six" ];
    widget.date = [NSDate dateWithTimeIntervalSince1970:123];
    const char bufferBytes2[] = { 65, 43, 21 };
    widget.buffer = [NSMutableData dataWithBytes:bufferBytes2 length:sizeof(bufferBytes2)];
    CLLocation *newGeoPoint = [[CLLocation alloc] initWithLatitude:-65.4 longitude:-32.1];
    widget.geopoint = newGeoPoint;

    ASYNC_TEST_START
    [widget saveWithSuccess:^{
        NSNumber *createdId = widget._id;
        [self.repository findById:createdId success:^(XXWidget *widget) {
            XCTAssertNotNil(widget._id, @"Invalid id");
            XCTAssertEqualObjects(widget.name, @"Barfoo", @"Invalid name.");
            XCTAssertEqual(widget.bars, 456, @"Invalid bars.");
            XCTAssertEqual(widget.flag, NO, @"Invalid flag.");
            XCTAssertEqualObjects(widget.data, (@{ @"data3": @3, @"data4": @4 }), @"Invalid data.");
            XCTAssertEqualObjects(widget.stringArray, (@[ @"four", @"five", @"six" ]), @"Invalid array.");
            XCTAssertEqualObjects(widget.date, [NSDate dateWithTimeIntervalSince1970:123], @"Invalid date.");
            const char bufferBytes2[] = { 65, 43, 21 };
            NSMutableData *testData = [NSMutableData dataWithBytes:bufferBytes2 length:sizeof(bufferBytes2)];
            XCTAssertEqualObjects(widget.buffer, testData, @"Invalid buffer.");
            XCTAssertEqual(widget.geopoint.coordinate.latitude, -65.4, @"Invalid latitude.");
            XCTAssertEqual(widget.geopoint.coordinate.longitude, -32.1, @"Invalid longitude.");
            ASYNC_TEST_SIGNAL
        } failure:ASYNC_TEST_FAILURE_BLOCK];
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

- (void)testRemove {
    ASYNC_TEST_START
    [self.repository findById:createdId success:^(XXWidget *widget) {
        [widget destroyWithSuccess:^{
            [self.repository findById:createdId success:^(XXWidget *widget) {
                XCTFail(@"Model found after removal");
            } failure:^(NSError *err) {
                ASYNC_TEST_SIGNAL
            }];
        } failure:ASYNC_TEST_FAILURE_BLOCK];
    } failure:ASYNC_TEST_FAILURE_BLOCK];
    ASYNC_TEST_END
}

@end
