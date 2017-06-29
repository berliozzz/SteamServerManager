

#import "SteamServerManager.h"
#import "AFNetworking.h"

@interface SteamServerManager ()

@property (strong, nonatomic) AFHTTPSessionManager *getOfferManager;
@property (strong, nonatomic) AFHTTPSessionManager *acceptOfferManager;
@property (strong, nonatomic) NSURLSessionConfiguration* sessionConfig;
@property (strong, nonatomic) NSArray *cookiesArray;
@property (strong, nonatomic) NSDictionary *cookieHeaders;

@end

@implementation SteamServerManager


+ (SteamServerManager*) sharedManager
{
    static SteamServerManager *manager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[SteamServerManager alloc] init];
    });
    
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self initCoockies];
        [self initManagers];
    }
    
    return self;
}


- (void) getTradeOfferWithId:(NSString*)offerId
                   onSuccess:(void(^)(NSString *response))success
                   onFailure:(void(^)(NSError *error))failure
{
    NSString *urlString = [NSString stringWithFormat:@"https://steamcommunity.com/tradeoffer/%@/", offerId];
    
    [self.getOfferManager POST:urlString
                    parameters:nil
                      progress:nil
                       success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject)
                           {
                           
                           if ([task.response isKindOfClass:[NSHTTPURLResponse class]])
                           {
                               NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
                               [self setCoockieWithHeaderResponse:[response allHeaderFields]];
                           }
                           
                           NSString *response;
                           
                           if (responseObject)
                           {
                               response = [NSString stringWithUTF8String:[responseObject bytes]];
                           }
                           else
                           {
                               NSLog(@"getTradeOffer: Unknow response for steam!");
                           }
                           
                           if (success)
                           {
                               success(response);
                           }
                           
                       } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                           
                           if (failure)
                           {
                               failure(error);
                           }
                       }];
}

- (void) acceptTradeOfferWithTradeOfferId:(NSString*)offerId
                                sessionId:(NSString*)sessionId
                                partnerId:(NSString*)partnerId
                                onSuccess:(void(^)(NSString *response))success
                                onFailure:(void(^)(NSError *error))failure
{
    NSString *urlString = [NSString stringWithFormat:@"https://steamcommunity.com/tradeoffer/%@/accept", offerId];
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                sessionId,          @"sessionid",
                                offerId,            @"tradeofferid",
                                @"1",               @"serverid",
                                partnerId,          @"partner",
                                @"",                @"captcha", nil];
    
    [self.acceptOfferManager.requestSerializer setValue:[NSString stringWithFormat:@"https://steamcommunity.com/tradeoffer/%@", offerId] forHTTPHeaderField:@"Referer"];
    
    [self.acceptOfferManager POST:urlString
                       parameters:parameters
                         progress:nil
                          success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                              
                              @try
                              {
                                  NSString *response;
                                  
                                  if (responseObject)
                                  {
                                      response = [NSString stringWithUTF8String:[responseObject bytes]];
                                  }
                                  else
                                  {
                                      NSLog(@"acceptTradeOffer: Unknow response for steam!");
                                  }
                                  
                                  if (success)
                                  {
                                      success(response);
                                  }
                              }
                              @catch (NSException *exception)
                              {
                                  NSLog(@"error steam: %@", exception);
                              }
                          }
                          failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error)
                          {
                              if (failure)
                              {
                                  failure(error);
                              }
                          }];
}

#pragma mark - Help Methods

- (void) initCoockies
{
    //добавляем куки из файла JSONData.txt
    NSError *error = nil;
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"JSONData" ofType:@"txt"];
    
    NSData *jsonData = [NSData dataWithContentsOfFile:filePath];
    
    NSArray *jsonArray = [NSJSONSerialization
                          JSONObjectWithData:jsonData
                          options:NSJSONReadingAllowFragments
                          error:&error];
    
    
    for (NSDictionary *dict in jsonArray)
    {
        NSMutableDictionary *prop = [[NSMutableDictionary alloc] init];
        
        [prop setObject:[dict objectForKey:@"domain"] forKey:NSHTTPCookieDomain];
        [prop setObject:[dict objectForKey:@"session"] forKey:NSHTTPCookieDiscard];
        [prop setObject:[dict objectForKey:@"path"] forKey:NSHTTPCookiePath];
        [prop setObject:[dict objectForKey:@"name"] forKey:NSHTTPCookieName];
        [prop setObject:[dict objectForKey:@"hostOnly"] forKey:NSHTTPCookieOriginURL];
        [prop setObject:[dict objectForKey:@"secure"] forKey:NSHTTPCookieSecure];
        [prop setObject:[dict objectForKey:@"value"] forKey:NSHTTPCookieValue];
        
        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:prop];
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
    }
}

- (void) initManagers
{
    /*
     инициализируем для каждого метода отдельный менеджер,
     т.к. для каждого нужны уникальные параметры
     */
    self.sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.sessionConfig.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyAlways;
    self.sessionConfig.HTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    self.cookiesArray = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    self.cookieHeaders = [NSHTTPCookie requestHeaderFieldsWithCookies: self.cookiesArray];
    
    //getOfferManager initialization
    self.getOfferManager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:self.sessionConfig];
    self.getOfferManager.responseSerializer = [AFHTTPResponseSerializer serializer];
    self.getOfferManager.requestSerializer = [AFHTTPRequestSerializer serializer];
    
    [self.getOfferManager.requestSerializer setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    [self.getOfferManager.requestSerializer setValue:@"gzip, deflate" forHTTPHeaderField:@"Acept-Encoding"];
    [self.getOfferManager.requestSerializer setValue:@"ru-RU,ru;q=0.8,en-US;q=0.6,en;q=0.4" forHTTPHeaderField:@"Acept-Language"];
    [self.getOfferManager.requestSerializer setValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
    [self.getOfferManager.requestSerializer setValue:@"application/x-www-form-urlencoded;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [self.getOfferManager.requestSerializer setValue:@"1" forHTTPHeaderField:@"DNT"];
    [self.getOfferManager.requestSerializer setValue:@"steamcommunity.com" forHTTPHeaderField:@"Host"];
    [self.getOfferManager.requestSerializer setValue:@"https://steamcommunity.com" forHTTPHeaderField:@"Origin"];
    [self.getOfferManager.requestSerializer setValue:@"steamcommunity.com" forHTTPHeaderField:@"Host"];
    [self.getOfferManager.requestSerializer setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/54.0.2840.98 Safari/537.36" forHTTPHeaderField:@"User-Agent"];
    [self.getOfferManager.requestSerializer setValue:[self.cookieHeaders objectForKey: @"Cookie" ] forHTTPHeaderField:@"Cookie"];
    
    
    //acceptOfferManager initialization
    self.acceptOfferManager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:self.sessionConfig];
    self.acceptOfferManager.responseSerializer = [AFHTTPResponseSerializer serializer];
    self.acceptOfferManager.requestSerializer = [AFHTTPRequestSerializer serializer];
    
    [self.acceptOfferManager.requestSerializer setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    [self.acceptOfferManager.requestSerializer setValue:@"gzip, deflate" forHTTPHeaderField:@"Acept-Encoding"];
    [self.acceptOfferManager.requestSerializer setValue:@"ru-RU,ru;q=0.8,en-US;q=0.6,en;q=0.4" forHTTPHeaderField:@"Acept-Language"];
    [self.acceptOfferManager.requestSerializer setValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
    //[self.acceptOfferManager.requestSerializer setValue:@"104" forHTTPHeaderField:@"Content-Length"];
    [self.acceptOfferManager.requestSerializer setValue:@"application/x-www-form-urlencoded;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    [self.acceptOfferManager.requestSerializer setValue:@"1" forHTTPHeaderField:@"DNT"];
    [self.acceptOfferManager.requestSerializer setValue:@"steamcommunity.com" forHTTPHeaderField:@"Host"];
    [self.acceptOfferManager.requestSerializer setValue:@"https://steamcommunity.com" forHTTPHeaderField:@"Origin"];
    [self.acceptOfferManager.requestSerializer setValue:@"steamcommunity.com" forHTTPHeaderField:@"Host"];
    [self.acceptOfferManager.requestSerializer setValue:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/54.0.2840.98 Safari/537.36" forHTTPHeaderField:@"User-Agent"];
    [self.acceptOfferManager.requestSerializer setValue:[self.cookieHeaders objectForKey: @"Cookie" ] forHTTPHeaderField:@"Cookie"];
}


@end
