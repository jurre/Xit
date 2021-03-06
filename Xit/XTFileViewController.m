#import "XTFileViewController.h"
#import "XTFileListDataSource.h"
#import "XTPreviewItem.h"
#import "XTRepository.h"
#import <RBSplitView.h>

@interface XTFileViewController ()

@end

@implementation XTFileViewController

- (void)setRepo:(XTRepository *)newRepo
{
  repo = newRepo;
  [fileListDS setRepo:newRepo];
  ((XTPreviewItem *)filePreview.previewItem).repo = newRepo;
}

- (void)awakeFromNib
{
  // -[NSOutlineView makeViewWithIdentifier:owner:] causes this to get called
  // again after the initial load.
  if ([[splitView subviews] count] == 2)
    return;

  // For some reason the splitview comes with preexisting subviews.
  NSArray *subviews = [[splitView subviews] copy];

  for (NSView *sub in subviews)
    [sub removeFromSuperview];
  [splitView addSubview:leftPane];
  [splitView addSubview:rightPane];
  [splitView setDivider:[NSImage imageNamed:@"splitter"]];
  [splitView setDividerThickness:1.0];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(fileSelectionChanged:)
             name:NSOutlineViewSelectionDidChangeNotification
           object:fileListOutline];
}

- (void)updatePreviewItem
{
  NSIndexSet *selection = [fileListOutline selectedRowIndexes];
  const NSUInteger selectionCount = [selection count];
  XTPreviewItem *previewItem = (XTPreviewItem *)filePreview.previewItem;

  if (previewItem == nil) {
    previewItem = [[XTPreviewItem alloc] init];
    previewItem.repo = repo;
    filePreview.previewItem = previewItem;
  }

  previewItem.commitSHA = repo.selectedCommit;
  if (selectionCount != 1) {
    [filePreview setHidden:YES];
    previewItem.path = nil;
    return;
  }
  [filePreview setHidden:NO];
  previewItem.path =
      [[fileListOutline itemAtRow:[selection firstIndex]] representedObject];
}

- (void)commitSelected:(NSNotification *)note
{
  [self refresh];
}

- (void)fileSelectionChanged:(NSNotification *)note
{
  [self refresh];
}

- (void)refresh
{
  [self updatePreviewItem];
  [filePreview refreshPreviewItem];
}

#pragma mark - NSOutlineViewDelegate

- (NSView *)outlineView:(NSOutlineView *)outlineView
     viewForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item
{
  if (outlineView == fileListOutline) {
    NSTableCellView *cell =
        [outlineView makeViewWithIdentifier:@"fileCell" owner:self];
    NSTreeNode *node = (NSTreeNode *)item;
    NSString *fileName = (NSString *)node.representedObject;

    if ([node isLeaf])
      cell.imageView.image = [[NSWorkspace sharedWorkspace]
          iconForFileType:[fileName pathExtension]];
    else
      cell.imageView.image = [NSImage imageNamed:NSImageNameFolder];
    cell.textField.stringValue = [fileName lastPathComponent];

    return cell;
  }
  return nil;
}

#pragma mark - RBSplitViewDelegate

const CGFloat kSplitterBonus = 4;

- (NSRect)splitView:(RBSplitView *)sender
         cursorRect:(NSRect)rect
         forDivider:(NSUInteger)divider
{
  if ([sender isVertical]) {
    rect.origin.x -= kSplitterBonus;
    rect.size.width += kSplitterBonus * 2;
  }
  return rect;
}

- (NSUInteger)splitView:(RBSplitView *)sender
        dividerForPoint:(NSPoint)point
              inSubview:(RBSplitSubview *)subview
{
  // Assume sender is the file list split view
  const NSRect subFrame = [subview frame];
  NSRect frame1, frame2, remainder;
  NSUInteger position = [subview position];
  NSRectEdge edge1 = [sender isVertical] ? NSMinXEdge : NSMinYEdge;
  NSRectEdge edge2 = [sender isVertical] ? NSMaxXEdge : NSMaxYEdge;

  NSDivideRect(subFrame, &frame1, &remainder, kSplitterBonus, edge1);
  NSDivideRect(subFrame, &frame2, &remainder, kSplitterBonus, edge2);

  if ([sender mouse:point inRect:frame1] && (position > 0))
    return position - 1;
  else if ([sender mouse:point inRect:frame2])
    return position;
  return NSNotFound;
}

@end
