/* Copyright © 2007-2008, The Sequential Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the Sequential Project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE Sequential Project ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE Sequential Project BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGXMLParser.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"

// Categories
#import "NSObjectAdditions.h"

@interface PGXMLParser (Private)

- (NSArray *)_classes;
- (void)_setClasses:(NSArray *)anArray;
- (BOOL)_hasSubparser;
- (PGXMLParser *)_subparser;

@end

@implementation PGXMLParser

#pragma mark Class Methods

+ (id)parserWithData:(NSData *)data
      baseURL:(NSURL *)URL
      classes:(NSArray *)classes
{
	PGXMLParser *const p = [[[self alloc] init] autorelease];
	[p setBaseURL:URL];
	[p _setClasses:classes];
	[p parseWithData:data];
	return p;
}
+ (BOOL)canParseTagPath:(NSString *)p
        attributes:(NSDictionary *)attrs
{
	return NO;
}

#pragma mark Instance Methods

- (NSURL *)baseURL
{
	if(!_baseURL) return [_parent baseURL];
	return [[_baseURL retain] autorelease];
}
- (void)setBaseURL:(NSURL *)URL
{
	if(URL == _baseURL) return;
	[_baseURL release];
	_baseURL = [URL copy];
}

#pragma mark -

- (void)parseWithData:(NSData *)data
{
	_tagPath = [@"/" copy];
	_parser = [[NSXMLParser alloc] initWithData:data];
	[_parser setDelegate:self];
	[_parser parse];
	[_parser release];
	_parser = nil;
	[_tagPath release];
	_tagPath = nil;
}

#pragma mark -

- (PGXMLParser *)parentParser
{
	return _parent;
}
- (NSArray *)subparsers
{
	return [[_subparsers copy] autorelease];
}
- (void)useSubparser:(PGXMLParser *)parser
{
	NSParameterAssert([parser isKindOfClass:[PGXMLParser class]]);
	NSParameterAssert(_parser);
	NSParameterAssert(!parser->_parent);
	[_subparsers addObject:parser];
	[_parser setDelegate:parser];
	parser->_parent = self;
	parser->_parser = _parser;
	parser->_initialTagPath = [_tagPath copy];
	parser->_tagPath = [_tagPath copy];
	[parser beganTagPath:_tagPath attributes:_attributes];
}

#pragma mark -

- (void)beganTagPath:(NSString *)p
        attributes:(NSDictionary *)attrs
{
	Class class;
	NSEnumerator *const classEnum = [[self _classes] objectEnumerator];
	while((class = [classEnum nextObject])) {
		if([self isKindOfClass:class] || ![class canParseTagPath:p attributes:attrs]) continue;
		[self useSubparser:[[[class alloc] init] autorelease]];
		return;
	}
}
- (NSMutableString *)contentStringForTagPath:(NSString *)p
{
	return nil;
}
- (void)endedTagPath:(NSString *)p {}

#pragma mark Private Protocol

- (NSArray *)_classes
{
	return _classes ? [[_classes retain] autorelease] : [_parent _classes];
}
- (void)_setClasses:(NSArray *)anArray
{
	[_classes autorelease];
	_classes = [anArray retain];
}
- (BOOL)_hasSubparser
{
	return 1 == [_subparsers count];
}
- (PGXMLParser *)_subparser
{
	return [self _hasSubparser] ? [_subparsers lastObject] : nil;
}

#pragma mark PGXMLParserNodeCreation Protocol

- (BOOL)createsMultipleNodes
{
	return [self _hasSubparser] ? [[_subparsers lastObject] createsMultipleNodes] : YES;
}

#pragma mark -

- (NSString *)title
{
	return [[self _subparser] title];
}
- (NSURL *)URL
{
	NSString *const URLString = [self URLString];
	return URLString ? [NSURL URLWithString:URLString relativeToURL:[self baseURL]] : nil;
}
- (NSError *)error
{
	NSString *const errorString = [self errorString];
	return errorString ? [NSError errorWithDomain:PGNodeErrorDomain code:PGGenericError userInfo:[NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey]] : nil;
}
- (id)info
{
	if([self createsMultipleNodes]) return nil;
	if(![_subparsers count]) {
		NSURL *const URL = [self URL];
		return URL ? [NSDictionary dictionaryWithObjectsAndKeys:URL, PGURLKey, nil] : nil;
	}
	NSMutableArray *const dicts = [NSMutableArray array];
	PGXMLParser *parser;
	NSEnumerator *const parserEnum = [_subparsers objectEnumerator];
	while((parser = [parserEnum nextObject])) [dicts addObjectsFromArray:[[parser info] AE_asArray]];
	return dicts;
}

#pragma mark -

- (NSString *)URLString
{
	return [[self _subparser] URLString];
}
- (NSString *)errorString
{
	return [[self _subparser] errorString];
}

#pragma mark -

- (NSArray *)nodesWithParentAdapter:(PGContainerAdapter *)parent
{
	if(![self createsMultipleNodes]) {
		PGNode *const node = [self nodeWithParentAdapter:parent];
		return node ? [NSArray arrayWithObject:node] : nil;
	}
	NSMutableArray *const nodes = [NSMutableArray array];
	PGXMLParser *subparser;
	NSEnumerator *const subparserEnum = [[self subparsers] objectEnumerator];
	while((subparser = [subparserEnum nextObject])) [nodes addObjectsFromArray:[subparser nodesWithParentAdapter:parent]];
	return nodes;
}
- (PGNode *)nodeWithParentAdapter:(PGContainerAdapter *)parent
{
	if([self isMemberOfClass:[PGXMLParser class]]) return [[_subparsers lastObject] nodeWithParentAdapter:parent];
	PGResourceIdentifier *const ident = [[self URL] AE_resourceIdentifier];
	if(!ident) return nil;
	[ident setCustomDisplayName:[self title] notify:NO];
	PGNode *const node = [[[PGNode alloc] initWithParentAdapter:parent document:nil identifier:ident dataSource:nil] autorelease];
	[node startLoadWithInfo:[self info]];
	return node;
}

#pragma mark NSXMLParserDelegateEventAdditions Protocol

- (void)parser:(NSXMLParser *)parser
        didStartElement:(NSString *)elementName
        namespaceURI:(NSString *)namespaceURI
        qualifiedName:(NSString *)qName
        attributes:(NSDictionary *)attributeDict
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	[_tagPath autorelease];
	_tagPath = [[_tagPath stringByAppendingPathComponent:elementName] copy];
	[[self contentStringForTagPath:_tagPath] setString:@""];
	[_attributes autorelease];
	_attributes = [attributeDict retain];
	[self beganTagPath:_tagPath attributes:attributeDict];
	[_attributes release];
	_attributes = nil;
	[pool release];
}
- (void)parser:(NSXMLParser *)parser
        foundCharacters:(NSString *)string
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	[[self contentStringForTagPath:_tagPath] appendString:string];
	[pool release];
}
- (void)parser:(NSXMLParser *)parser
        didEndElement:(NSString *)elementName
        namespaceURI:(NSString *)namespaceURI
        qualifiedName:(NSString *)qName
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	[self endedTagPath:_tagPath];
	if([_initialTagPath isEqualToString:_tagPath]) {
		[_parser setDelegate:_parent];
		[_parent parser:parser didEndElement:elementName namespaceURI:namespaceURI qualifiedName:qName];
	}
	[_tagPath autorelease];
	_tagPath = [[_tagPath stringByDeletingLastPathComponent] copy];
	[pool release];
}

#pragma mark NSObject Protocol

- (BOOL)respondsToSelector:(SEL)sel
{
	return [super respondsToSelector:sel] ? YES : [[self _subparser] respondsToSelector:sel];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		_subparsers = [[NSMutableArray alloc] init];
	}
	return self;
}
- (void)dealloc
{
	[_baseURL release];
	[_subparsers release];
	[_initialTagPath release];
	[_tagPath release];
	[_classes release];
	[super dealloc];
}

#pragma mark -

- (IMP)methodForSelector:(SEL)sel
{
	return [super respondsToSelector:sel] ? [super methodForSelector:sel] : [[self _subparser] methodForSelector:sel];
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
	return [super respondsToSelector:sel] ? [super methodSignatureForSelector:sel] : [[self _subparser] methodSignatureForSelector:sel];
}
- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	[anInvocation invokeWithTarget:[self _subparser]];
}

@end
