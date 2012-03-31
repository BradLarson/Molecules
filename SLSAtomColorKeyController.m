//
//  SLSAtomColorKeyController.m
//  Molecules
//
//  The source code for Molecules is available under a BSD license.  See License.txt for details.
//

#import "SLSAtomColorKeyController.h"
#import "SLSOpenGLESRenderer.h"
#import "SLSMoleculeTableViewController.h"
#import "SLSMoleculeLibraryTableCell.h"

typedef enum { COLORKEY_HYDROGEN, COLORKEY_CARBON, COLORKEY_NITROGEN, COLORKEY_OXYGEN, COLORKEY_FLUORINE, COLORKEY_SODIUM, COLORKEY_MAGNESIUM, COLORKEY_SILICON, COLORKEY_PHOSPHOROUS, COLORKEY_SULFUR, COLORKEY_CHLORINE, COLORKEY_CALCIUM, COLORKEY_IRON, COLORKEY_ZINC, COLORKEY_BROMINE, COLORKEY_CADMIUM, COLORKEY_IODINE, COLORKEY_UNKNOWN, COLORKEY_NUM_ATOMTYPES } SLSAtomTypeForTable;

@interface SLSAtomColorKeyController ()

@end

@implementation SLSAtomColorKeyController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.title = NSLocalizedStringFromTable(@"Color Key", @"Localized", nil);

        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
		self.contentSizeForViewInPopover = CGSizeMake(250.0f, 864.0f);
//		self.contentSizeForViewInPopover = CGSizeMake(200.0f, 864.0f);
    }

    self.tableView.backgroundColor = [UIColor blackColor];
    self.tableView.separatorColor = [UIColor clearColor];
    self.tableView.rowHeight = 48.0;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return COLORKEY_NUM_ATOMTYPES;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ColorTableKey"];
	NSInteger index = [indexPath row];
    
    if (cell == nil) 
    {
        cell = [[SLSMoleculeLibraryTableCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ColorTableKey"];
        
//        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.textColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        // Specular highlight
        CAGradientLayer *newGlow = [[CAGradientLayer alloc] init];
        CGRect newGlowFrame = CGRectMake(0.0, 7.0, self.view.frame.size.width, 14.0);
        newGlow.frame = newGlowFrame;
        
        UIColor *topColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.0f];
        UIColor *middleColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.40f];
        UIColor *bottomColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.00f];
        
        newGlow.colors = [NSArray arrayWithObjects:(id)[topColor CGColor], (id)[middleColor CGColor], (id)[bottomColor CGColor], nil];
        [cell.layer insertSublayer:newGlow atIndex:10];

        // Bottom shadow
        CAGradientLayer *newShadow = [[CAGradientLayer alloc] init];
        CGRect newShadowFrame = CGRectMake(0, 24.0, self.view.frame.size.width, 24.0);
        newShadow.frame = newShadowFrame;
        
        UIColor *topShadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0f];
        UIColor *middleShadowColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5f];
        
        newShadow.colors = [NSArray arrayWithObjects:(id)[topShadowColor CGColor], (id)[middleShadowColor CGColor], nil];
        [cell.layer insertSublayer:newShadow atIndex:10];

        // Top shadow
        CAGradientLayer *newShadow2 = [[CAGradientLayer alloc] init];
        CGRect newShadowFrame2 = CGRectMake(0, 0.0, self.view.frame.size.width, 10.0);
        newShadow2.frame = newShadowFrame2;
        
        UIColor *topShadowColor2 = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.2f];
        UIColor *middleShadowColor2 = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.0f];
        
        newShadow2.colors = [NSArray arrayWithObjects:(id)[topShadowColor2 CGColor], (id)[middleShadowColor2 CGColor], nil];
        [cell.layer insertSublayer:newShadow2 atIndex:9];
    }		
    
//    SLSAtomType atomType = CARBON;
    switch (index)
    {
        case COLORKEY_CARBON:
        {
//            atomType = CARBON;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Carbon", @"Localized", nil);  
        }; break;
        case COLORKEY_HYDROGEN:
        {
//            atomType = HYDROGEN;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Hydrogen", @"Localized", nil);  
        }; break;
        case COLORKEY_NITROGEN:
        {
//            atomType = NITROGEN;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Nitrogen", @"Localized", nil);  
        }; break;
        case COLORKEY_OXYGEN:
        {
//            atomType = OXYGEN;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Oxygen", @"Localized", nil);  
        }; break;
        case COLORKEY_FLUORINE:
        {
//            atomType = FLUORINE;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Fluorine", @"Localized", nil);  
        }; break;
        case COLORKEY_SODIUM:
        {
//            atomType = SODIUM;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Sodium", @"Localized", nil);  
        }; break;
        case COLORKEY_MAGNESIUM:
        {
//            atomType = MAGNESIUM;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Magnesium", @"Localized", nil);  
        }; break;
        case COLORKEY_SILICON:
        {
//            atomType = SILICON;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Silicon", @"Localized", nil);  
        }; break;
        case COLORKEY_PHOSPHOROUS:
        {
//            atomType = PHOSPHOROUS;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Phosphorous", @"Localized", nil);  
        }; break;
        case COLORKEY_SULFUR:
        {
//            atomType = SULFUR;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Sulfur", @"Localized", nil);  
        }; break;
        case COLORKEY_CHLORINE:
        {
//            atomType = CHLORINE;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Chlorine", @"Localized", nil);  
        }; break;
        case COLORKEY_CALCIUM:
        {
//            atomType = CALCIUM;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Calcium", @"Localized", nil);  
        }; break;
        case COLORKEY_IRON:
        {
//            atomType = IRON;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Iron", @"Localized", nil);  
        }; break;
        case COLORKEY_ZINC:
        {
//            atomType = ZINC;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Zinc", @"Localized", nil);  
        }; break;
        case COLORKEY_BROMINE:
        {
//            atomType = BROMINE;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Bromine", @"Localized", nil);  
        }; break;
        case COLORKEY_CADMIUM:
        {
//            atomType = CADMIUM;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Cadmium", @"Localized", nil);  
        }; break;
        case COLORKEY_IODINE:
        {
//            atomType = IODINE;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Iodine", @"Localized", nil);  
        }; break;
        default: 
        {
//            atomType = UNKNOWN;
            cell.textLabel.text = NSLocalizedStringFromTable(@"Unknown", @"Localized", nil);  
        }; break;
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath 
{
    cell.backgroundColor = [UIColor blackColor];
    
    switch ([indexPath row])
    {
        case COLORKEY_CARBON: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[CARBON].redComponent / 255.0) green:((float)atomProperties[CARBON].greenComponent / 255.0) blue:((float)atomProperties[CARBON].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_HYDROGEN: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[HYDROGEN].redComponent / 255.0) green:((float)atomProperties[HYDROGEN].greenComponent / 255.0) blue:((float)atomProperties[HYDROGEN].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_NITROGEN: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[NITROGEN].redComponent / 255.0) green:((float)atomProperties[NITROGEN].greenComponent / 255.0) blue:((float)atomProperties[NITROGEN].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_OXYGEN: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[OXYGEN].redComponent / 255.0) green:((float)atomProperties[OXYGEN].greenComponent / 255.0) blue:((float)atomProperties[OXYGEN].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_FLUORINE: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[FLUORINE].redComponent / 255.0) green:((float)atomProperties[FLUORINE].greenComponent / 255.0) blue:((float)atomProperties[FLUORINE].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_SODIUM: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[SODIUM].redComponent / 255.0) green:((float)atomProperties[SODIUM].greenComponent / 255.0) blue:((float)atomProperties[SODIUM].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_MAGNESIUM: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[MAGNESIUM].redComponent / 255.0) green:((float)atomProperties[MAGNESIUM].greenComponent / 255.0) blue:((float)atomProperties[MAGNESIUM].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_SILICON: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[SILICON].redComponent / 255.0) green:((float)atomProperties[SILICON].greenComponent / 255.0) blue:((float)atomProperties[SILICON].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_PHOSPHOROUS: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[PHOSPHOROUS].redComponent / 255.0) green:((float)atomProperties[PHOSPHOROUS].greenComponent / 255.0) blue:((float)atomProperties[PHOSPHOROUS].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_SULFUR: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[SULFUR].redComponent / 255.0) green:((float)atomProperties[SULFUR].greenComponent / 255.0) blue:((float)atomProperties[SULFUR].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_CHLORINE: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[CHLORINE].redComponent / 255.0) green:((float)atomProperties[CHLORINE].greenComponent / 255.0) blue:((float)atomProperties[CHLORINE].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_CALCIUM: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[CALCIUM].redComponent / 255.0) green:((float)atomProperties[CALCIUM].greenComponent / 255.0) blue:((float)atomProperties[CALCIUM].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_IRON: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[IRON].redComponent / 255.0) green:((float)atomProperties[IRON].greenComponent / 255.0) blue:((float)atomProperties[IRON].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_ZINC: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[ZINC].redComponent / 255.0) green:((float)atomProperties[ZINC].greenComponent / 255.0) blue:((float)atomProperties[ZINC].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_BROMINE: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[BROMINE].redComponent / 255.0) green:((float)atomProperties[BROMINE].greenComponent / 255.0) blue:((float)atomProperties[BROMINE].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_CADMIUM: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[CADMIUM].redComponent / 255.0) green:((float)atomProperties[CADMIUM].greenComponent / 255.0) blue:((float)atomProperties[CADMIUM].blueComponent / 255.0) alpha:1.0]; break;
        case COLORKEY_IODINE: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[IODINE].redComponent / 255.0) green:((float)atomProperties[IODINE].greenComponent / 255.0) blue:((float)atomProperties[IODINE].blueComponent / 255.0) alpha:1.0]; break;
        default: cell.backgroundColor = [UIColor colorWithRed:((float)atomProperties[UNKNOWN].redComponent / 255.0) green:((float)atomProperties[UNKNOWN].greenComponent / 255.0) blue:((float)atomProperties[UNKNOWN].blueComponent / 255.0) alpha:1.0]; break;
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

@end
