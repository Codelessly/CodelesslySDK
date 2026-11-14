# SSUI parity

Owner, 2026-11-14: "fully recreate all the SSUI components we have in CodelesslySDK as part of the default set.
A lot of the defaults you're using are made up and not the professional SSUI designs we have in our component
library."

The source is `Researchy/soft_saas_ui/src/components` (164 components) with `SSUI_PATTERNS.md`. A component is
**here** when the SDK draws it from SSUI's own values: as a control the tree draws (a render object) or as a
document in `components/` written by `tool/generate.py`. Each new one is built from the source file's numbers
(sizes, radii, paddings, type, colours by token), rendered, and looked at beside the source.

**Here: 44. Still to rebuild: 120.**

## Here

| SSUI component | Design-system document | Control the tree draws |
|---|---|---|
| Avatar | Avatar |  |
| Badge | Badge |  |
| Banner | Banner |  |
| Button | Button | buttons (filled, outlined, text, elevated) |
| Carousel |  | pageView |
| Checkbox | Checkbox | checkbox |
| Chip | Chip | chip family |
| CountBadge | CountBadge |  |
| DatePicker |  | datePicker |
| Dialog | Dialog | confirm action / modal |
| Dropdown |  | dropdown |
| EmptyState | EmptyState |  |
| Field | Field |  |
| FloatingActionButton |  | floatingActionButton |
| IconBox | IconBox |  |
| IconButton | IconButton | iconButton |
| InlineStat | InlineStat |  |
| LoadingSpinner |  | activityIndicator |
| Pagination |  | pagination |
| ProgressIndicator | ProgressBar | progressBar |
| RadioButton | Radio | radio |
| SegmentedControl | SegmentedControl | segmentedButton |
| Select | Select | dropdown |
| Slider | Slider | slider |
| StatsRow | StatTile (dashboard density), InlineStat (compact) |  |
| StatusBadge | StatusBadge |  |
| StatusDot | StatusDot |  |
| Switch | Switch | switch |
| Table |  | tableView |
| TextArea | TextArea | textField (maxLines) |
| TextField | TextInput | textField |
| TextInput | TextInput | textField |
| TimePicker |  | timePicker |
| Toast |  | showToast action |
| ToggleRow | ToggleRow |  |
| Tooltip | Tooltip | tooltip behavior |
| Skeleton | Skeleton |  |
| ErrorBar | ErrorBar |  |
| FeatureBulletItem | FeatureBulletItem |  |
| SectionCard | SectionCard |  |
| MetaInfo | MetaInfo |  |
| Hyperlink | Hyperlink |  |
| NotificationBadge | NotificationBadge |  |
| PulsingDots | PulsingDots |  |

Also here with no source file of the same name: Card, ListRow, SectionHeader, Tabs.

## Still to rebuild

In the order planned: what generated UI reaches for first, then the application chrome.

### Status and feedback (9)

StatusIndicator, RunningIndicator, RadialProgress, StackedProgressBar, BatchProgressBar, ConnectionStatus, CloudSyncIndicator, DiffStatsBadge, LoadMore

### Text and small content (14)

TextItem, TextExpandable, TextInputLabel, CodeBlock, CodePreview, CopyButton, DownloadButton, BackButton, AddButton, UpgradeButton, SplitButton, MenuButton, ThemeToggle, TabToggle

### Cards and rows (25)

Panel, CardActions, ProviderCard, ProviderIcon, ProviderPill, FolderCard, ResourceCard, ResourceChip, PersonChip, AgentChip, DocumentItem, FileListItem, FileMetadataCard, ActionListItem, SelectableListRow, RunRecordRow, RunHistoryList, StatusCardList, StatsCarousel, ModelAvatarStack, OptionIcon, OnboardingBanner, TrialBanner, PromptBanner, AuthPromptBanner

### Inputs (21)

SearchBar, FullWidthSearchInput, HeaderSearchInput, Combobox, NumberInput, NumberPresetInput, Stepper, ColorInput, AuthInput, ExtensionChipsInput, FileUploader, ImageUpload, IconSelect, IconSegmentedControl, DropdownMultiselect, MultiSelectDropdown, HierarchicalPicker, RichTextField, RichTextToolbar, PromptInput, PromptInputWithBanner

### Navigation and chrome (23)

Breadcrumb, BrowserTabs, ChipTabs, TabBarWithBadges, TabOverflowScroll, SplitPaneTabs, PageControl, StepIndicator, Sidebar, SidebarTogglePattern, NavigationMenu, CompactAppBar, WindowToolbar, SectionToolbar, PaneToolbar, Toolbar, SectionCategoryHeaderFull, StatusCategoryHeader, FilterLegend, CollapsibleSection, ScrollToBottomFAB, CanvasShell, ResizableRow

### Menus and overlays (14)

ContextMenu, AddContextMenu, FileTreeContextMenu, MenuPopover, SortMenu, UserMenu, ModelSelectMenu, ProjectSelector, WorkspaceSwitcher, CommandPalette, NotePopover, SlidingPanel, ViewerDialog, VariableContractHover

### Data and specialised (14)

Tree, FileTree, DiffViewer, Terminal, HistoryTimeline, DateTimelineAxis, ImageGallery, NestedTaskLedger, ReorderableList, ReorderGhost, SuggestionReviewItem, CompactSuggestionReviewItem, SuggestionActionObject, VariableContractList
