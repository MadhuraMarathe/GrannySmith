//
//  NSString+ParsingHelper.m
//  i2
//
//  Created by Bao Lei on 7/14/11.
//  Copyright 2011 hulu. All rights reserved.
//

#import "NSString+ParsingHelper.h"
#import "HUFancyTextDefines.h"

@implementation NSString (ParsingHelper)

- (NSMutableArray*) linesWithWidth:(CGFloat)width font:(UIFont*)font firstLineWidth:(CGFloat)firstLineWidth limitLineCount:(int)limitLineCount {
    #ifdef DEBUG_MODE
    DebugLog(@"LineBreak - The string: %@, 1st line: %f, other lines: %f", self, firstLineWidth, width);
    #endif
    
    NSMutableString* firstLineBlocked = [NSMutableString string];
    if (firstLineWidth < width) {
        CGFloat spaceWidth = [@" " sizeWithFont:font].width;
        int spacesToStart = (int)ceilf((width - firstLineWidth) / spaceWidth);
        for (int i=0; i<spacesToStart; i++) {
            [firstLineBlocked appendString:@" "];
        }
        // there will always be 1 or 2 space mismatch..
        while ([firstLineBlocked sizeWithFont:font].width < width - firstLineWidth) {
            [firstLineBlocked appendString:@" "];
        }
    }
    
    NSMutableArray* lines = [[NSMutableArray alloc] init];
    NSMutableString* currentLine = [[NSMutableString alloc] init];

    // estimate the number of characters for each line
    // int step = (int) (width / [[self substringToIndex:1] sizeWithFont:font].width);
    int step = 1; 
    // using 1 is the safest (but slightly slower) solution. Will double check and optimize this later.
    
    for (int i = 0; i<self.length; i=i+step){
    
        if (limitLineCount>0 && lines.count == limitLineCount-1) {
            [lines addObject:[self substringFromIndex:i]];
            release(currentLine);
            return autoreleased(lines);
        }
        
        // if the rest of the string begins with \n
        BOOL beginsWithBR = [[self substringWithRange:NSMakeRange(i, 1)] isEqualToString:@"\n"];
                
        // deal with \n first
        if (beginsWithBR){
            //DebugLog(@"This block begins with BR");
            
            if (currentLine.length>0) {
                //DebugLog(@"adding line before br: %@",currentLine);
                [lines addObject: [NSString stringWithString:currentLine]];
                [currentLine setString:@""];
                
                // before adding the next line, we need to check limitLineCount
                if (limitLineCount>0 && lines.count == limitLineCount-1) {
                    [lines addObject:[self substringFromIndex:i]];
                    release(currentLine);
                    return autoreleased(lines);
                }
                
            }
            
            [lines addObject:@""];
            i = i - step + 1;
            continue;
        }
    
        NSString* character = [self substringWithRange:NSMakeRange(i, i+step<=self.length?step:(self.length-i) )];
        int brPosition = [character rangeOfString:@"\n"].location;
        if (brPosition != NSNotFound) {
            #ifdef DEBUG_MODE
            DebugLog(@"Found BR in this block.. position: %d", brPosition);
            #endif
            character = [character substringToIndex:brPosition];
            i = i + brPosition - step;
        }

        if (!currentLine.length && lines.count) {
            [currentLine appendFormat:@"%@", trim(character)];
        }
        else {
            [currentLine appendFormat:@"%@", character];
        }
        
        NSString* lineToCalcWidth = (lines.count && firstLineBlocked.length) ? currentLine : [NSString stringWithFormat:@"%@%@", firstLineBlocked, currentLine];
        CGSize appleSize = [ lineToCalcWidth
                            sizeWithFont:font
                            constrainedToSize:CGSizeMake(width,1000.f) 
                            lineBreakMode:UILineBreakModeWordWrap];
        
        #ifdef DEBUG_MODE
        DebugLog(@"[%d] current line: %@. width to confine: %f, apple width: %f", i, currentLine, width, appleSize.width);
        #endif
        
        if (appleSize.height > font.lineHeight) {
            // a new line is created
            CGFloat idealWidth = appleSize.width;
            
            // special case: if the 1st character can't fit into the first line
            if (i==0 && firstLineWidth<width) {
                i = -1;
                [currentLine setString:@""];
                [lines addObject:@""];
                continue;
            }
            
            while ([lineToCalcWidth sizeWithFont:font].width > idealWidth) {
                [currentLine deleteCharactersInRange:NSMakeRange(currentLine.length-1, 1)];
                lineToCalcWidth = (lines.count && firstLineBlocked.length) ? currentLine : [NSString stringWithFormat:@"%@%@", firstLineBlocked, currentLine];
                i--;
            }
            
            #ifdef DEBUG_MODE
            DebugLog(@"adding line: %@",currentLine);
            #endif
            
            [lines addObject: [NSString stringWithString:currentLine]];
            [currentLine setString:@""];
            
            #ifdef DEBUG_MODE
            DebugLog(@"i rewinded to %d",i);
            #endif
        }
        
    }
    if (currentLine.length>0) {
        #ifdef DEBUG_MODE
        DebugLog(@"adding line: %@",currentLine);
        #endif
        [lines addObject: [NSString stringWithString:currentLine]];
    }
 
    release(currentLine);
    #ifdef DEBUG_MODE
    DebugLog(@"lines: %@", lines);
    #endif
    return autoreleased(lines);
}


- (NSMutableArray*) linesWithWidth:(CGFloat)width font:(UIFont*)font {
    return [self linesWithWidth:width font:font firstLineWidth:width limitLineCount:0];
}

-(NSString*)stringByTrimmingLeadingWhitespace {
    if (! trim(self).length) {
        return @"";
    }
    
    int i = 0;
    while ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[self characterAtIndex:i]]) {
        i++;
    }
    return [self substringFromIndex:i];
}

- (NSString*)stringByTrimmingTrailingWhitespace {
    if (! trim(self).length) {
        return @"";
    }
    
    int i = self.length - 1;
    while ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[self characterAtIndex:i]]) {
        i--;
    }
    return [self substringToIndex:i+1];
}

- (NSString*)firstNonWhitespaceCharacterSince:(int)location foundAt:(int*)foundLocation {
    if (! trim(self).length) {
        return @"";
    }
    BOOL found = NO;
    int i;
    NSString* character;
    for (i=location; i<self.length; i++) {
        character = [self substringWithRange:NSMakeRange(i, 1)];
        if (trim(character).length) {
            found = YES;
            break;
        }
    }
    if (found) {
        *foundLocation = i;
        return character;
    }
    else {
        *foundLocation = self.length;
        return @"";
    }
}

@end