import garciadelcastillo.dashedlines.*;
DashedLines dash;

ArrayList<Tree> trees;
ArrayList<Tag> tags;
int log_count=0;
int numb_comm=0; // Number of communications
int max_memory=0;


float globalScale = 1.;
float eraseRadius = 30;
String tool = "new_logs";

int tag_diameter;
int tree_diameter;
int commRadius;
int inspected_tag_index=-1; // Used to draw the currently inspected tag's suggest new cam location
int newLogTimer=0;

// Messages parameters
int messageTimer = 0;
int logMessageTimer=0;
String messageText = "";
String inspectionText = "";

// toggles
boolean new_logs=false;
boolean communicate=false;



void setup () {
  size(1300, 731); //Ratio of 1.777..7..7
  textSize(16);
  recalculateConstants();
  tags = new ArrayList<Tag>();
  trees = new ArrayList<Tree>();
  placeTreesnTags();
  dash = new DashedLines(this);
  dash.pattern(2, 3);
}

void recalculateConstants () {
  tag_diameter=(int) (8.*globalScale);
  tree_diameter=(int) (12.*globalScale);

  commRadius = (int) (220.*globalScale);
}


void placeTreesnTags() {
  for (int x = 100; x < width - 50; x+= 80) {
    for (int y = 100; y < height - 100; y+= 80) {
      boolean tagged=false;
      int randint=(int)random(5);
      if (randint==1) {
        tagged=true;
      }
      trees.add(new Tree(x + random(-30, 30), y + random(-30, 30), tagged));
      if (tagged) tags.add(trees.get(trees.size()-1).tag);
    }
  }
  
  for (Tag tag: tags){
    tag.getNeighbours();
  }
  
  //Remove isolated tags:
  removeIsolatedTags();
}

void draw () {
  if(new_logs){
    increment(); // Increment timer of new log
    if(newLogTimer==0) createLog();
  }

  // Black background:
  noStroke();
  colorMode(HSB);
  fill(0, 100);
  rect(0, 0, width, height);
  
  if (tool == "erase") {
    noFill();
    stroke(0, 100, 260);
    rect(mouseX - eraseRadius, mouseY - eraseRadius, eraseRadius * 2, eraseRadius *2);
    if (mousePressed) {
      erase();
    }
  } else if (tool=="tag_eraser") {
    noFill();
    stroke(0, 100, 260);
    rect(mouseX - eraseRadius, mouseY - eraseRadius, eraseRadius * 2, eraseRadius *2);
    if (mousePressed) {
      eraseTag();
    }
  } else if (tool == "trees") {
    noStroke();
    fill(20, 255, 90);
    ellipse(mouseX, mouseY, tree_diameter, tree_diameter);
  } else if (tool == "tags") {
    noStroke();
    fill(100);
    ellipse(mouseX, mouseY, tag_diameter, tag_diameter);
  }

  for (int i = 0; i <tags.size(); i++) {
    Tag current = tags.get(i);
    current.go();
    current.draw();
    
    // Draw inspected tag suggested new cam:
    //if (i==inspected_tag_index){
    //  noFill();
    //  stroke(0, 255, 200); // Color = 0 (red)
    //  dash.ellipse(current.suggested_new_cam.x, current.suggested_new_cam.y, tag_diameter, tag_diameter);
    //}
  }

  for (int i = 0; i <trees.size(); i++) {
    Tree current = trees.get(i);
    current.draw();
  }
  
  if (messageTimer > 0) {
    messageTimer--;
  }
  if (logMessageTimer > 0) {
    logMessageTimer--;
  }
  drawGUI();
}

void keyPressed () {
  if (key == 'c') {
    tool = "tags";
    message("Add tags");
  } else if (key == 'i') {
    tool = "inspect";
    message("Inspect tag");
  } else if (key == 't') {
    tool = "trees";
    message("Place trees");
  } else if (key == 'e') {
    tool = "erase";
    message("Eraser");
  } else if (key == 'z') {
    tool = "tag_eraser";
    message("Tag eraser");
  } else if (key == 'x') {
    tool = "extract";
    message("Extract logs");
  } else if (key == '-') {
    message("Decreased scale");
    globalScale *= 0.8;
  } else if (key == '=') {
    message("Increased Scale");
    globalScale /= 0.8;
  } else if (key == 's') {
    new_logs = new_logs ? false : true;
    if(new_logs) message("New logs ");
    else message("Stop new logs ");
  } else if (key == 'o') {
    communicate = communicate ? false : true;
    if(communicate) message("Communication on");
    else message("Communication off");
  } else if (key == 'r') { // Reset
    n_tags=0;
    numb_comm=0;
    log_count=0;
    max_memory=0;
    tags.clear();
    trees.clear();
    placeTreesnTags();
  }
  recalculateConstants();
}

void drawGUI() {
  textSize(16);
  if (messageTimer > 0) {
    fill((min(30, messageTimer) / 30.0) * 255.0);

    text(messageText, 10, height - 25);
  }
  if (logMessageTimer > 0){
    fill((min(30, logMessageTimer) / 30.0) * 255.0);

    text("Log added !", 630, height - 25);
  }
  fill(255.0); // Text color
  text(inspectionText, 150, height - 45);
  if (inspectionText!="") {
    noFill();
    stroke(255.0);
    rect(140, height - 65, 400, 60);
  }
  fill(255.0); // Text color
  text("Max memory : " + max_memory, 730, height-25);
  text("Total comms: " + numb_comm, 850, height-25);
  text("Total logs: " + log_count, 970, height - 25);
  text("Total tags: " + tags.size(), 1070, height - 25);
  text("Total trees: " + trees.size(), 1170, height - 25);
}

void mousePressed () {
  switch (tool) {
  case "tags":
    int index = getAimedTreeIndex(); // Returns the index of the tree in trees aimed by the mouse
    trees.get(index).tag(); // Create Tag object associated with aimed_tree
    tags.add(trees.get(index).tag); // Add this new object to the list of tags
    break;

  case "trees":
    trees.add(new Tree(mouseX, mouseY, false));
    break;

  case "inspect":
    //Tree aimed_tree_ = getAimedTree(mouseX,mouseY);
    inspection();
    break;
    
  case "extract":
    extraction();
    break;
  }
}

void erase () {
  for (int i = tags.size()-1; i > -1; i--) {
    Tag t = tags.get(i);
    if (abs(t.tree.pos.x - mouseX) < eraseRadius && abs(t.tree.pos.y - mouseY) < eraseRadius) {
      tags.remove(i);
    }
  }

  for (int i = trees.size()-1; i > -1; i--) {
    Tree t = trees.get(i);
    if (abs(t.pos.x - mouseX) < eraseRadius && abs(t.pos.y - mouseY) < eraseRadius) {
      trees.remove(i);
    }
  }
}

void eraseTag () {
  for (int i = trees.size()-1; i > -1; i--) {
    Tree t = trees.get(i);
    if (abs(t.pos.x - mouseX) < eraseRadius && abs(t.pos.y - mouseY) < eraseRadius) {
      trees.get(i).tagged=false;
    }
  }

  for (int i = tags.size()-1; i > -1; i--) {
    Tag t = tags.get(i);
    if (abs(t.tree.pos.x - mouseX) < eraseRadius && abs(t.tree.pos.y - mouseY) < eraseRadius) {
      tags.remove(i);
    }
  }
}

void message (String in) {
  messageText = in;
  messageTimer = (int) frameRate * 3;
}

void inspection () {
  inspected_tag_index = getAimedTagIndex(); // Returns the index of the tag in tags aimed by the mouse
  Tag aimed_tag=tags.get(inspected_tag_index);
  String tag_id="Tag ID: "+aimed_tag.id;
  String vp = "Vuln prob: "+aimed_tag.vuln_prob;
  String entropy= "Entropy: "+aimed_tag.entropy;
  String hops="Onehops: "+aimed_tag.onehops.size() + "  Twohops: "+aimed_tag.twohops.size();
  String logs="Logs: ";
  String most_vuln= "Most vuln: " + aimed_tag.most_vuln.size();
  for(int i =0;i<aimed_tag.logs.getRowCount();i++){
    logs+=" ";
    logs+=aimed_tag.logs.getInt(i,"log_numb");
    logs+=",";
  }
  
  inspectionText=tag_id + "    " +vp+ "     " + entropy + "    " + most_vuln + '\n'+ hops + "    " + logs;
}

void extraction () {
  inspected_tag_index = getAimedTagIndex(); // Returns the index of the tag in tags aimed by the mouse
  Tag aimed_tag=tags.get(inspected_tag_index);
  Table all_logs=aimed_tag.extractLogsNetwork(aimed_tag,0); // Exctract the logs of the network from this node
  all_logs.sort("log_numb");
  println("Number of collected logs: "+all_logs.getRowCount());
  println("Collected logs are: ");
  for (int i =0; i < all_logs.getRowCount();i++){
    println(all_logs.getInt(i,"log_numb"));
  }
  //log_count=0; // No more logs in the network anymore
}

int getAimedTreeIndex() {
  float shortest_distance=height*width;
  PVector aimed_pos= new PVector(mouseX, mouseY);
  int aimed_tree_index=0;

  for (int i = 0; i<trees.size(); i++) {
    float distance = PVector.dist(trees.get(i).pos, aimed_pos);
    if (distance<shortest_distance) {
      shortest_distance=distance;
      aimed_tree_index=i;
    }
  }
  return aimed_tree_index;
}

int getAimedTagIndex() {
  float shortest_distance=height*width;
  PVector aimed_pos= new PVector(mouseX, mouseY);
  int aimed_tag_index=0;

  for (int i = 0; i<tags.size(); i++) {
    float distance = PVector.dist(tags.get(i).tree.pos, aimed_pos);
    if (distance<shortest_distance) {
      shortest_distance=distance;
      aimed_tag_index=i;
    }
  }
  return aimed_tag_index;
}

void createLog(){
  int tag_index = (int)random(tags.size());
  tags.get(tag_index).addLog(log_count,tags.get(tag_index).id);
  logMessageTimer = (int) (frameRate * 0.6);
  log_count++;
}

void removeIsolatedTags(){
  for (int i=tags.size()-1;i>=0;i--){
    Tag tag= tags.get(i);
    if(tag.onehops.size()==0){
      tag.tree.tagged=false;
      tags.remove(i);
    }
    else if(tag.onehops.size()==1 && tag.twohops.size()==0){
      tag.tree.tagged=false;
      tags.remove(i);
    }
  }
}
void increment () {
    newLogTimer = (newLogTimer + 1) % 20; // The newLogTimer is between 0 and 19
}
