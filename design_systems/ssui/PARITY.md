# SSUI parity

Owner, 2026-11-14: "fully recreate all the SSUI components we have in CodelesslySDK as part of the default set.
A lot of the defaults you're using are made up and not the professional SSUI designs we have in our component
library."

The source is `Researchy/soft_saas_ui/src/components` (164 components) with `SSUI_PATTERNS.md`. A component is
**here** when the SDK draws it from SSUI's own values: as a control the tree draws (a render object) or as a
document in `components/` written by `tool/generate.py`. Each new one is built from the source file's numbers
(sizes, radii, paddings, type, colors by token), rendered, and looked at beside the source.

**Here: 138. Still to rebuild: 26.**

## Here

| SSUI component | Design-system document | Control the tree draws |
|---|---|---|
| ActionListItem | ActionListItem |  |
| AddButton | AddButton |  |
| AgentChip | AgentChip |  |
| AuthInput | AuthInput |  |
| AuthPromptBanner | AuthPromptBanner |  |
| Avatar | Avatar |  |
| BackButton | BackButton |  |
| Badge | Badge |  |
| Banner | Banner |  |
| BatchProgressBar | BatchProgressBar |  |
| Breadcrumb | Breadcrumb |  |
| BrowserTabs | BrowserTabs |  |
| Button | Button | buttons (filled, outlined, text, elevated) |
| CardActions | CardActions |  |
| Carousel |  | pageView |
| Checkbox | Checkbox | checkbox |
| Chip | Chip | chip family |
| ChipTabs | ChipTabs |  |
| CloudSyncIndicator | CloudSyncIndicator |  |
| CodeBlock | CodeBlock |  |
| CodePreview | CodePreview |  |
| CollapsibleSection | CollapsibleSection |  |
| ColorInput | ColorInput |  |
| Combobox | Combobox |  |
| CommandPalette | CommandPalette |  |
| CompactAppBar | CompactAppBar |  |
| ConnectionStatus | ConnectionStatus |  |
| ContextMenu | ContextMenu |  |
| CopyButton | CopyButton |  |
| CountBadge | CountBadge |  |
| DatePicker |  | datePicker |
| Dialog | Dialog | confirm action / modal |
| DiffStatsBadge | DiffStatsBadge |  |
| DiffViewer | DiffViewer |  |
| DocumentItem | DocumentItem |  |
| DownloadButton | DownloadButton |  |
| Dropdown |  | dropdown |
| DropdownMultiselect | DropdownMultiselect |  |
| EmptyState | EmptyState |  |
| ErrorBar | ErrorBar |  |
| FeatureBulletItem | FeatureBulletItem |  |
| Field | Field |  |
| FileListItem | FileListItem |  |
| FileMetadataCard | FileMetadataCard |  |
| FileUploader | FileUploader |  |
| FilterLegend | FilterLegend |  |
| FloatingActionButton |  | floatingActionButton |
| FullWidthSearchInput | FullWidthSearchInput |  |
| HeaderSearchInput | HeaderSearchInput |  |
| HistoryTimeline | HistoryTimeline |  |
| Hyperlink | Hyperlink |  |
| IconBox | IconBox |  |
| IconButton | IconButton | iconButton |
| IconSegmentedControl | IconSegmentedControl |  |
| IconSelect | IconSelect |  |
| ImageUpload | ImageUpload |  |
| InlineStat | InlineStat |  |
| LoadingSpinner |  | activityIndicator |
| LoadMore | LoadMore |  |
| MenuButton | MenuButton |  |
| MenuPopover | MenuPopover (with MenuItem) |  |
| MetaInfo | MetaInfo |  |
| ModelAvatarStack | ModelAvatarStack |  |
| ModelSelectMenu | ModelSelectMenu |  |
| NavigationMenu | NavigationMenu |  |
| NotePopover | NotePopover |  |
| NotificationBadge | NotificationBadge |  |
| NumberInput | NumberInput |  |
| OnboardingBanner | OnboardingBanner |  |
| OptionIcon | OptionIcon |  |
| PageControl | PageControl |  |
| Pagination |  | pagination |
| Panel | Panel |  |
| PaneToolbar | PaneToolbar |  |
| PersonChip | PersonChip |  |
| ProgressIndicator | ProgressBar | progressBar |
| PromptBanner | PromptBanner |  |
| PromptInput | PromptInput |  |
| ProviderCard | ProviderCard |  |
| ProviderIcon | ProviderIcon |  |
| ProviderPill | ProviderPill |  |
| PulsingDots | PulsingDots |  |
| RadialProgress | RadialProgress |  |
| RadioButton | Radio | radio |
| ResourceCard | ResourceCard |  |
| ResourceChip | ResourceChip |  |
| RichTextToolbar | RichTextToolbar |  |
| RunHistoryList | RunHistoryList |  |
| RunningIndicator | RunningIndicator |  |
| RunRecordRow | RunRecordRow |  |
| ScrollToBottomFAB | ScrollToBottomFAB |  |
| SearchBar | SearchBar |  |
| SectionCard | SectionCard |  |
| SectionCategoryHeaderFull | SectionCategoryHeaderFull |  |
| SectionToolbar | SectionToolbar |  |
| SegmentedControl | SegmentedControl | segmentedButton |
| Select | Select | dropdown |
| SelectableListRow | SelectableListRow |  |
| Sidebar | Sidebar |  |
| Skeleton | Skeleton |  |
| Slider | Slider | slider |
| SlidingPanel | SlidingPanel |  |
| SortMenu | SortMenu |  |
| SplitButton | SplitButton |  |
| SplitPaneTabs | SplitPaneTabs |  |
| StackedProgressBar | StackedProgressBar |  |
| StatsCarousel | StatsCarousel |  |
| StatsRow | StatTile (dashboard density), InlineStat (compact) |  |
| StatusBadge | StatusBadge |  |
| StatusCardList | StatusCardList (with StatusCard) |  |
| StatusCategoryHeader | StatusCategoryHeader |  |
| StatusDot | StatusDot |  |
| StatusIndicator | StatusIndicator |  |
| StepIndicator | StepIndicator |  |
| Stepper | Stepper |  |
| Switch | Switch | switch |
| TabBarWithBadges | TabBarWithBadges |  |
| Table |  | tableView |
| TabToggle | TabToggle |  |
| Terminal | Terminal |  |
| TextArea | TextArea | textField (maxLines) |
| TextExpandable | TextExpandable |  |
| TextField | TextInput | textField |
| TextInput | TextInput | textField |
| TextInputLabel | TextInputLabel |  |
| TextItem | TextItem |  |
| ThemeToggle | ThemeToggle |  |
| TimePicker |  | timePicker |
| Toast |  | showToast action |
| ToggleRow | ToggleRow |  |
| Tooltip | Tooltip | tooltip behavior |
| Tree | Tree |  |
| TrialBanner | TrialBanner |  |
| UpgradeButton | UpgradeButton |  |
| UserMenu | UserMenu |  |
| ViewerDialog | ViewerDialog |  |
| WindowToolbar | WindowToolbar |  |
| WorkspaceSwitcher | WorkspaceSwitcher |  |

Also here with no source file of the same name: Card, ListRow, SectionHeader, Tabs.

## Still to rebuild

In the order planned: what generated UI reaches for first, then the application chrome.

### Cards and rows (1)

FolderCard

### Inputs (6)

NumberPresetInput, ExtensionChipsInput, MultiSelectDropdown, HierarchicalPicker, RichTextField, PromptInputWithBanner

### Navigation and chrome (5)

TabOverflowScroll, SidebarTogglePattern, Toolbar, CanvasShell, ResizableRow

### Menus and overlays (4)

AddContextMenu, FileTreeContextMenu, ProjectSelector, VariableContractHover

### Data and specialized (10)

FileTree, DateTimelineAxis, ImageGallery, NestedTaskLedger, ReorderableList, ReorderGhost, SuggestionReviewItem, CompactSuggestionReviewItem, SuggestionActionObject, VariableContractList
