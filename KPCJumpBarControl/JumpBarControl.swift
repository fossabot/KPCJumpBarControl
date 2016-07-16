//
//  JumpBarControl.swift
//  KPCJumpBarControl
//
//  Created by Cédric Foellmi on 08/05/16.
//  Licensed under the MIT License (see LICENSE file)
//

import AppKit

enum IndexPathError: ErrorType {
    case Empty(String)
    case Invalid(String)
}

let KPCJumpBarControlAccessoryMenuLabelTag: NSInteger = -1;
let KPCJumpBarControlTag: NSInteger = -9999999;

public class JumpBarControl : NSControl, JumpBarSegmentControlDelegate {
    public weak var delegate: JumpBarControlDelegate? = nil
    public private(set) var selectedIndexPath: NSIndexPath? = nil
    
    private var hasCompressedSegments: Bool = false
    private var isSelected: Bool = false
    
    // MARK: - Overrides
    
    override public var flipped: Bool {
        get { return true }
    }
    
    override public var enabled: Bool {
        didSet {
            for segmentControl in self.segmentControls() {
                segmentControl.enabled = self.enabled
            }
            self.setNeedsDisplay()
        }
    }
    
    override public var frame: NSRect {
        didSet {
            self.layoutSegmentsIfNeeded(withNewSize:super.frame.size)
        }
    }

    override public var bounds: NSRect {
        didSet {
            self.layoutSegmentsIfNeeded(withNewSize:super.bounds.size)
        }
    }
    
    // MARK: - Constructors

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setup()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }

    private func setup() {
        self.tag = KPCJumpBarControlTag;
        self.enabled = true;
    }

    override public func menuForEvent(event: NSEvent) -> NSMenu? {
        return nil;
    }
    
    // MARK: - Window

    override public func viewWillMoveToWindow(newWindow: NSWindow?) {
        super.viewWillMoveToWindow(newWindow)
        
        NSNotificationCenter.defaultCenter().removeObserver(self, name:NSWindowDidResignKeyNotification, object:self.window)
        NSNotificationCenter.defaultCenter().removeObserver(self, name:NSWindowDidBecomeKeyNotification, object:self.window)
    }
    
    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector:#selector(NSControl.setNeedsDisplay),
                                                         name:NSWindowDidResignKeyNotification,
                                                         object:self.window)
        
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector:#selector(NSControl.setNeedsDisplay),
                                                         name:NSWindowDidBecomeKeyNotification,
                                                         object:self.window)
    }

    // MARK: - Public Methods
    
    public func useItemsTree(itemsTree: Array<JumpBarItemProtocol>) {
        self.segmentControls().forEach { $0.removeFromSuperview() }
        self.selectedIndexPath = nil
        
        self.menu = NSMenu.menuWithSegmentsTree(itemsTree, target:self, action:#selector(JumpBarControl.selectJumpBarControlItem(_:)))
        
        self.layoutSegments();
        
        if self.menu?.itemArray.count > 0 {
            self.selectJumpBarControlItem(self.menu!.itemArray.first!)
        }
    }
    
    @objc private func selectJumpBarControlItem(sender: NSMenuItem) {
    
        let nextSelectedIndexPath = sender.indexPath()
        let nextSelectedItem: JumpBarItemProtocol = sender.representedObject as! JumpBarItemProtocol
    
        self.delegate?.jumpBarControl(self, willSelectItem: nextSelectedItem, atIndexPath: nextSelectedIndexPath)
        
        self.removeSegments(fromLevel: nextSelectedIndexPath.length)
        self.selectedIndexPath = nextSelectedIndexPath
        self.layoutSegments()
    
        self.delegate?.jumpBarControl(self, didSelectItem: nextSelectedItem, atIndexPath: nextSelectedIndexPath)
    }
    
    public func item(atIndexPath indexPath: NSIndexPath) -> JumpBarItemProtocol? {
        guard let item = self.menu?.menuItemAtIndexPath(self.selectedIndexPath) else {
            return nil
        }
        return item.representedObject as? JumpBarItemProtocol // Return representedObject as NSMenuItem are kept hidden
    }
    
    public func selectedItem() -> JumpBarItemProtocol? {
        if let ip = self.selectedIndexPath {
            return self.item(atIndexPath: ip)
        }
        return nil
    }
    
    public func select() {
        self.isSelected = true
        for segmentControl in self.segmentControls() {
            segmentControl.select()
        }
        self.setNeedsDisplay()
    }

    public func deselect() {
        self.isSelected = false
        for segmentControl in self.segmentControls() {
            segmentControl.deselect()
        }
        self.setNeedsDisplay()
    }
    
    
    // MARK: - Layout
    
    private func removeSegments(fromLevel level: Int) {
        if level < self.selectedIndexPath?.length {
            for l in level..<self.selectedIndexPath!.length {
                if let superfluousSegmentControl = self.segmentControlAtLevel(l, createIfNecessary: false) {
                    superfluousSegmentControl.removeFromSuperview()
                }
            }
        }
    }
    
    private func layoutSegmentsIfNeeded(withNewSize size:CGSize) {

        if (self.hasCompressedSegments)  {
            self.layoutSegments(); // always layout segments when compressed.
        }
        else {
            if let lastSegmentControl = self.segmentControlAtLevel(self.selectedIndexPath!.length-1, createIfNecessary: false) {
                let maxNewControlWidth = size.width
                let currentControlWidth = CGRectGetMaxX(lastSegmentControl.frame)
                if (currentControlWidth > maxNewControlWidth) {
                    self.layoutSegments()
                }
            }
        }
    }
    
    private func layoutSegments() {
        let totalWidth = self.prepareSegmentsLayout()
        if totalWidth <= 0 {
            return
        }
        
        self.hasCompressedSegments = CGRectGetWidth(self.frame) < totalWidth
        
        var originX = CGFloat(0);
        var widthReduction = CGFloat(0)
        
        if self.hasCompressedSegments {
            widthReduction = (totalWidth - CGRectGetWidth(self.frame))/CGFloat(self.selectedIndexPath!.length)
        }
        
        for position in 0..<self.selectedIndexPath!.length {
            let segmentControl = self.segmentControlAtLevel(position)!
            var frame = segmentControl.frame
            frame.origin.x = originX
            frame.size.width -= widthReduction
            originX += frame.size.width
            segmentControl.frame = frame
        }        
    }
    
    private func prepareSegmentsLayout() -> CGFloat {
        guard self.selectedIndexPath?.length > 0 else {
            return CGFloat(0)
        }
        
        var currentMenu = self.menu
        var totalWidth = CGFloat(0)
        
        for position in 0..<self.selectedIndexPath!.length {
            let index = self.selectedIndexPath!.indexAtPosition(position)
            
            let segment = self.segmentControlAtLevel(position)!
            segment.isLastSegment = (position == self.selectedIndexPath!.length-1)
            segment.indexInPath = index
            segment.select()
            
            let item = currentMenu!.itemAtIndex(index)
            segment.representedObject = item!.representedObject as? JumpBarItemProtocol;
            currentMenu = item!.submenu
            
            segment.sizeToFit()
            totalWidth += CGRectGetWidth(segment.frame)
        }
        
        return totalWidth
    }
    
    // MARK: - Drawing
    
    override public func drawRect(dirtyRect: NSRect) {
    
        var newRect = dirtyRect
        newRect.size.height = self.bounds.size.height;
        newRect.origin.y = 0;
    
        var mainGradient: NSGradient? = nil;
        if (!self.isSelected || !self.enabled || !(self.window?.keyWindow)!) {
            mainGradient = NSGradient(startingColor:NSColor(calibratedWhite:0.96, alpha:1.0),
                                      endingColor:NSColor(calibratedWhite:0.94, alpha:1.0));                
        }
        else {
            mainGradient = NSGradient(startingColor:NSColor(calibratedWhite:0.85, alpha:1.0),
                                      endingColor:NSColor(calibratedWhite:0.83, alpha:1.0));
        }
    
        mainGradient!.drawInRect(newRect, angle:-90);
    
        NSColor(calibratedWhite:0.7, alpha:1.0).set()
        // bottom line
        newRect.size.height = 1;
        NSRectFill(newRect);
        // top line
        newRect.origin.y = self.frame.size.height - 1;
        NSRectFill(newRect);
    }
    
    
    // MARK: - Helpers
    
    private func segmentControlAtLevel(level: Int, createIfNecessary: Bool = true) -> JumpBarSegmentControl? {
        
        var segmentControl: JumpBarSegmentControl? = self.viewWithTag(level) as! JumpBarSegmentControl?;
        
        if (segmentControl == nil || segmentControl == self) && createIfNecessary == true { // Check for == self is when at root.
            segmentControl = JumpBarSegmentControl()
            segmentControl!.tag = level;
            segmentControl!.frame = NSMakeRect(0, 0, 0, self.frame.size.height);
            segmentControl!.delegate = self;
            segmentControl!.enabled = self.enabled;
            self.addSubview(segmentControl!)
        }
        
        return segmentControl
    }
    
    private func segmentControls() -> Array<JumpBarSegmentControl> {
        return self.subviews.filter({ $0.isKindOfClass(JumpBarSegmentControl) }) as! Array<JumpBarSegmentControl>
    }
    
    // MARK: - JumpBarSegmentControlDelegate
    
    func jumpBarSegmentControlDidReceiveMouseDown(segmentControl: JumpBarSegmentControl) {
        
        let subIndexPath = self.selectedIndexPath!.subIndexPathToPosition(segmentControl.tag+1); // To be inclusing, one must add 1
        let clickedMenu = self.menu!.menuItemAtIndexPath(subIndexPath)!.menu;

        var items = [JumpBarItemProtocol]()
        for menuItem in clickedMenu!.itemArray {
            items.append(menuItem.representedObject as! JumpBarItemProtocol)
        }
    
        self.delegate?.jumpBarControl(self, willOpenMenuAtIndexPath:subIndexPath, withItems:items)
        
        // Avoid to call menuWillOpen: as it will duplicate with popUpMenuPositioningItem:...
        let menuDelegate = clickedMenu!.delegate;
        clickedMenu!.delegate = nil;
    
        let xPoint = (self.tag == KPCJumpBarItemControlAccessoryMenuLabelTag) ? CGFloat(-9) : CGFloat(-16);
        
        clickedMenu!.popUpMenuPositioningItem(clickedMenu?.itemAtIndex(segmentControl.indexInPath),
                                              atLocation:NSMakePoint(xPoint , segmentControl.frame.size.height - 4),
                                              inView:segmentControl)

        clickedMenu!.delegate = menuDelegate;

        items = [JumpBarItemProtocol]()
        for menuItem in clickedMenu!.itemArray {
            items.append(menuItem.representedObject as! JumpBarItemProtocol)
        }

        self.delegate?.jumpBarControl(self, didOpenMenuAtIndexPath:subIndexPath, withItems:items)
    }
}



