//import garciadelcastillo.dashedlines.*;
//DashedLines dash;

//Simualtion parameters:
boolean gradient_on =false;

ArrayList<Tree> trees;
ArrayList<Tag> tags;

int log_count=0;
int numb_comm=0; // Number of communications
int numb_setup_comm=0;
int max_memory=0;


float globalScale = 1.;
float eraseRadius = 30;
String tool = "new_logs";

int tag_diameter;
int tree_diameter;
int commRadius;
int inspected_tag_index=-1; // Used to draw the currently inspected tag's suggested new cam location
int newLogTimer=0;

// Messages parameters
int messageTimer = 0;
int logMessageTimer=0;
String messageText = "";
String inspectionText = "";
String logMessageText= "";

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
  //dash = new DashedLines(this);
  //dash.pattern(2, 3);
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
  
  
  // run getNeighbours() twice to make sure two-hops are configurated too !
  for (Tag tag: tags){
    tag.getNeighbours();
    numb_setup_comm+=tag.onehops.size();
  }
  for (Tag tag: tags){
    tag.getNeighbours();
    numb_setup_comm+=tag.onehops.size();
  }
  
  //Remove isolated tags:
  removeIsolatedTags();
  
  for(Tag tag : tags){
    tag.calcVulnProb(); // Computes vp and entropy
    tag.getBottlenecks();
    tag.getMostVulnNeighb(); // Finds the most vulnerable onehops
    if(gradient_on){
      if(tag.entropy>0) tag.updateEntrGrad(tag.entropy,tag,tag.id);
      tag.prev_entropy=tag.entropy;
    }
  }
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
    numb_setup_comm=0;
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

    text(logMessageText, 590, height - 25);
  }
  fill(255.0); // Text color
  text(inspectionText, 110, height - 45);
  if (inspectionText!="") {
    noFill();
    stroke(255.0);
    rect(100, height - 65, 550, 60);
  }
  fill(255.0); // Text color
  text("Largest memory : " + max_memory, 690, height - 25);
  text("# SU comms: " + numb_setup_comm, 830,height - 25);
  text("# comms: " + numb_comm, 960, height - 25);
  text("# logs: " + log_count, 1050, height - 25);
  text("# tags: " + tags.size(), 1120, height - 25);
  text("# trees: " + trees.size(), 1200, height - 25);
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
  String most_vuln= "Most vuln: " + aimed_tag.least_vuln.size();
  String entr_grad= "Entr grad: " + aimed_tag.entr_grad;
  for(int i =0;i<aimed_tag.logs.getRowCount();i++){
    logs+=" ";
    logs+=aimed_tag.logs.getInt(i,"log_numb");
    logs+=",";
  }
  
  inspectionText=tag_id + "   " +vp+ "    " + entropy + "   " + most_vuln + "  "+ entr_grad+ '\n'+ hops + "    " + logs;
}

void runExperiment(){
  //Randomly damage network
  
  
  //Extract from random node
  inspected_tag_index=(int)random(tags.size());
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
  tags.get(tag_index).newLog(log_count);
  logMessageText="New log at " + tags.get(tag_index).id;
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
