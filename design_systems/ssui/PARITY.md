# SSUI parity

Owner, 2026-11-14: "fully recreate all the SSUI components we have in CodelesslySDK as part of the default set.
A lot of the defaults you're using are made up and not the professional SSUI designs we have in our component
library."

The source is `Researchy/soft_saas_ui/src/components` (164 components) with `SSUI_PATTERNS.md`. A component is
**here** when the SDK draws it from SSUI's own values: as a control the tree draws (a render object) or as a
document in `components/` written by `tool/generate.py`. Each new one is built from the source file's numbers
(sizes, radii, paddings, type, colors by token), rendered, and looked at beside the source.

**Here: 62. Still to rebuild: 102.**

## Here

| SSUI component | Design-system document | Control the tree draws |
|---|---|---|
| AddButton | AddButton |  |
| Avatar | Avatar |  |
| BackButton | BackButton |  |
| Badge | Badge |  |
| Banner | Banner |  |
| Button | Button | buttons (filled, outlined, text, elevated) |
| CardActions | CardActions |  |
| Carousel |  | pageView |
| Checkbox | Checkbox | checkbox |
| Chip | Chip | chip family |
| ConnectionStatus | ConnectionStatus |  |
| CopyButton | CopyButton |  |
| CountBadge | CountBadge |  |
| DatePicker |  | datePicker |
| Dialog | Dialog | confirm action / modal |
| DiffStatsBadge | DiffStatsBadge |  |
| Dropdown |  | dropdown |
| EmptyState | EmptyState |  |
| ErrorBar | ErrorBar |  |
| FeatureBulletItem | FeatureBulletItem |  |
| Field | Field |  |
| FileListItem | FileListItem |  |
| FloatingActionButton |  | floatingActionButton |
| Hyperlink | Hyperlink |  |
| IconBox | IconBox |  |
| IconButton | IconButton | iconButton |
| InlineStat | InlineStat |  |
| LoadingSpinner |  | activityIndicator |
| LoadMore | LoadMore |  |
| MetaInfo | MetaInfo |  |
| NotificationBadge | NotificationBadge |  |
| OptionIcon | OptionIcon |  |
| Pagination |  | pagination |
| Panel | Panel |  |
| PersonChip | PersonChip |  |
| ProgressIndicator | ProgressBar | progressBar |
| ProviderCard | ProviderCard |  |
| ProviderIcon | ProviderIcon |  |
| ProviderPill | ProviderPill |  |
| PulsingDots | PulsingDots |  |
| RadialProgress | RadialProgress |  |
| RadioButton | Radio | radio |
| ResourceChip | ResourceChip |  |
| SectionCard | SectionCard |  |
| SegmentedControl | SegmentedControl | segmentedButton |
| Select | Select | dropdown |
| Skeleton | Skeleton |  |
| Slider | Slider | slider |
| StatsRow | StatTile (dashboard density), InlineStat (compact) |  |
| StatusBadge | StatusBadge |  |
| StatusDot | StatusDot |  |
| StatusIndicator | StatusIndicator |  |
| Switch | Switch | switch |
| Table |  | tableView |
| TextArea | TextArea | textField (maxLines) |
| TextField | TextInput | textField |
| TextInput | TextInput | textField |
| TextInputLabel | TextInputLabel |  |
| TimePicker |  | timePicker |
| Toast |  | showToast action |
| ToggleRow | ToggleRow |  |
| Tooltip | Tooltip | tooltip behavior |

Also here with no source file of the same name: Card, ListRow, SectionHeader, Tabs.

## Still to rebuild

In the order planned: what generated UI reaches for first, then the application chrome.

### Status and feedback (4)

RunningIndicator, StackedProgressBar, BatchProgressBar, CloudSyncIndicator

### Text and small content (10)

TextItem, TextExpandable, CodeBlock, CodePreview, DownloadButton, UpgradeButton, SplitButton, MenuButton, ThemeToggle, TabToggle

### Cards and rows (16)

FolderCard, ResourceCard, AgentChip, DocumentItem, FileMetadataCard, ActionListItem, SelectableListRow, RunRecordRow, RunHistoryList, StatusCardList, StatsCarousel, ModelAvatarStack, OnboardingBanner, TrialBanner, PromptBanner, AuthPromptBanner

### Inputs (21)

SearchBar, FullWidthSearchInput, HeaderSearchInput, Combobox, NumberInput, NumberPresetInput, Stepper, ColorInput, AuthInput, ExtensionChipsInput, FileUploader, ImageUpload, IconSelect, IconSegmentedControl, DropdownMultiselect, MultiSelectDropdown, HierarchicalPicker, RichTextField, RichTextToolbar, PromptInput, PromptInputWithBanner

### Navigation and chrome (23)

Breadcrumb, BrowserTabs, ChipTabs, TabBarWithBadges, TabOverflowScroll, SplitPaneTabs, PageControl, StepIndicator, Sidebar, SidebarTogglePattern, NavigationMenu, CompactAppBar, WindowToolbar, SectionToolbar, PaneToolbar, Toolbar, SectionCategoryHeaderFull, StatusCategoryHeader, FilterLegend, CollapsibleSection, ScrollToBottomFAB, CanvasShell, ResizableRow

### Menus and overlays (14)

ContextMenu, AddContextMenu, FileTreeContextMenu, MenuPopover, SortMenu, UserMenu, ModelSelectMenu, ProjectSelector, WorkspaceSwitcher, CommandPalette, NotePopover, SlidingPanel, ViewerDialog, VariableContractHover

### Data and specialized (14)

Tree, FileTree, DiffViewer, Terminal, HistoryTimeline, DateTimelineAxis, ImageGallery, NestedTaskLedger, ReorderableList, ReorderGhost, SuggestionReviewItem, CompactSuggestionReviewItem, SuggestionActionObject, VariableContractList
